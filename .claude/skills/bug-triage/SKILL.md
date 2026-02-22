---
name: bug-triage
description: Triage open bug issues from Forgejo. Use when asked to triage bugs, review open issues, prioritize work, check what needs fixing, or do a bug review.
allowed-tools: Bash(curl *), Bash(jq *), Bash(yq *), Bash(date *), Bash(git *), Bash(nix *), Bash(just *)
argument-hint: optional filter (e.g., 'nas-01 only', 'critical', 'all')
---

# Bug Triage Skill

Fetch open bug issues from Forgejo, prioritize by severity, present to the user for triage decisions, then act on each — either investigating, fixing via worktree + PR, deferring, or closing.

## Forgejo API Setup

```bash
TOKEN=$(yq -r '.logins[0].token' ~/.config/tea/config.yml)
FORGEJO_URL="https://forgejo.bobtail-clownfish.ts.net"
REPO="bcotton/nix-config"
```

**Important**: Use `yq -r` (raw output) to avoid quoted strings.

## Step 1: Fetch Open Bug Issues

```bash
curl -sf -H "Authorization: token $TOKEN" \
  "$FORGEJO_URL/api/v1/repos/$REPO/issues?state=open&labels=bug&limit=50&sort=created&direction=desc" \
  | jq '.[] | {number, title, created_at, body: (.body[:200])}'
```

If the user specified a filter (e.g., "nas-01 only"), filter results by hostname prefix in the title.

## Step 2: Triage & Prioritize

Classify each issue into a priority level based on its title, body, and optionally a live Loki check:

| Priority | Criteria | Examples |
|----------|----------|---------|
| **P0 Critical** | Hardware failure, data loss risk, fleet-wide outage | SMART failures, ZFS FAULTED, all hosts affected |
| **P1 High** | Host not auto-upgrading, service persistently down, backup failures | Auto-upgrade PATH issues, restic failures |
| **P2 Medium** | Noisy errors (>100/day), stuck imports, misconfigured services | Radarr import loops, DHCP reservation failures |
| **P3 Low** | Cosmetic, informational, minor noise | Logging format issues, non-impacting warnings |

### Live Status Check (optional)

For each issue, optionally query Loki to check if the error is still actively occurring:

```bash
LOKI=$(curl -sf --max-time 3 https://loki.bobtail-clownfish.ts.net/ready >/dev/null 2>&1 \
  && echo "https://loki.bobtail-clownfish.ts.net" \
  || echo "http://nas-01.lan:3100")

curl -sG "$LOKI/loki/api/v1/query_range" \
  --data-urlencode 'query=<relevant LogQL>' \
  --data-urlencode "start=$(date -d '1 hour ago' +%s)" \
  --data-urlencode "end=$(date +%s)" \
  --data-urlencode 'limit=5' \
  --data-urlencode 'direction=backward' | jq '.data.result | length'
```

Mark issues as "still active" or "not seen recently" in the triage table.

## Step 3: Present to User

Show a prioritized summary table:

```markdown
| # | Pri | Issue | Host | Status | Type |
|---|-----|-------|------|--------|------|
| 47 | P1 | auto-upgrade extraScript fails... | nix-01 | Active | Config change |
| 46 | P1 | SMART command failures on disk... | imac-01 | Active | Investigation |
| 48 | P2 | Radarr import failure for stuck... | nas-01 | Active | Config change |
```

**Type** is your initial classification:
- **Config change** — the fix is a known code/config modification (add a package, change a setting, open a port, fix a path)
- **Investigation** — root cause is unclear, need to dig into logs and code first

## Step 4: Iterate Through Issues

For each issue (highest priority first), present the issue details and ask the user how to proceed. Options:

1. **Fix now (config change)** — create worktree, make the fix, build, test, commit, create PR
2. **Fix now (investigation)** — dig into logs/code, then propose a fix interactively
3. **Defer** — leave open, optionally add a comment noting why
4. **Close as known/expected** — close the issue with a comment explaining it's expected behavior
5. **Close as resolved** — issue was already fixed, close it
6. **Need more info** — run additional Loki queries or inspect the system before deciding

Wait for the user's decision on each issue before proceeding to the next.

## Step 5: Config Change Workflow

When the user chooses "Fix now (config change)":

### 5a. Create worktree

```bash
ISSUE_NUM=<N>
BRANCH="fix/issue-${ISSUE_NUM}"

# Create branch and worktree from current main
cd /home/bcotton/nix-config/default
git worktree add "../fix-issue-${ISSUE_NUM}" -b "$BRANCH"
```

### 5b. Make the fix

Work in the worktree directory:
```bash
cd "/home/bcotton/nix-config/fix-issue-${ISSUE_NUM}"
```

Edit the relevant files to fix the issue. Use the issue body for context on what needs to change.

### 5c. Build and test

```bash
# Build the affected host configuration
nix build ".#nixosConfigurations.<hostname>.config.system.build.toplevel" --no-link
```

If the build fails, fix the issue and rebuild.

### 5d. Commit

```bash
git add <changed-files>
git commit -m "$(cat <<'EOF'
<short description of fix>

Fixes #<N>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

### 5e. Push and create PR

```bash
git push -u origin "$BRANCH"
```

Create PR via Forgejo API:

```bash
curl -sf -X POST -H "Authorization: token $TOKEN" -H "Content-Type: application/json" \
  "$FORGEJO_URL/api/v1/repos/$REPO/pulls" \
  -d "$(cat <<PAYLOAD
{
  "title": "<short description>",
  "body": "## Summary\n\n<what this fixes and why>\n\nFixes #${ISSUE_NUM}\n\n## Test plan\n\n- [ ] \`nix build\` succeeds for affected host\n- [ ] Deploy and verify fix\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)",
  "head": "${BRANCH}",
  "base": "main"
}
PAYLOAD
)"
```

### 5f. Return to main

```bash
cd /home/bcotton/nix-config/default
```

Tell the user the PR URL and that the worktree can be cleaned up after merge:
```bash
git worktree remove "../fix-issue-${ISSUE_NUM}"
```

## Step 6: Investigation Workflow

When the user chooses "Fix now (investigation)":

1. **Query Loki** for recent occurrences of the error (use loki-query patterns)
2. **Search the codebase** for relevant config files, module definitions, service configs
3. **Present findings** to the user with root cause analysis
4. **If a fix is identified**, ask the user if they want to proceed with the config change workflow (Step 5)
5. **If unclear**, suggest next steps (SSH into the host, check hardware, manual inspection)

## Step 7: Close/Comment Actions

### Close an issue

```bash
curl -sf -X PATCH -H "Authorization: token $TOKEN" -H "Content-Type: application/json" \
  "$FORGEJO_URL/api/v1/repos/$REPO/issues/${ISSUE_NUM}" \
  -d '{"state": "closed"}'
```

### Add a comment

```bash
curl -sf -X POST -H "Authorization: token $TOKEN" -H "Content-Type: application/json" \
  "$FORGEJO_URL/api/v1/repos/$REPO/issues/${ISSUE_NUM}/comments" \
  -d "$(cat <<PAYLOAD
{
  "body": "<comment text>\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)"
}
PAYLOAD
)"
```

### Close with comment (combined)

For "close as known/expected" or "close as resolved", add the comment first, then close.

## Guidelines

1. **Always confirm with the user** before closing issues or creating PRs. Never auto-close.
2. **One issue at a time** — complete the action for one issue before moving to the next.
3. **Config changes are isolated** — each fix gets its own worktree and branch. Never mix fixes for different issues.
4. **Build before committing** — always verify `nix build` succeeds before committing.
5. **Reference the issue** — use `Fixes #N` in commit messages and PR bodies so Forgejo auto-links them.
6. **Don't duplicate work** — if an issue was already fixed in an earlier commit on main, just close it as resolved.
7. **Worktree naming** — use `fix-issue-<N>` for the worktree directory and `fix/issue-<N>` for the branch name.
