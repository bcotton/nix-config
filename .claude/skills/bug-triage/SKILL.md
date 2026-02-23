---
name: bug-triage
description: Triage open bug issues from Forgejo. Use when asked to triage bugs, review open issues, prioritize work, check what needs fixing, or do a bug review.
allowed-tools: Bash(curl *), Bash(jq *), Bash(yq *), Bash(date *), Bash(git *), Bash(nix *), Bash(just *), Bash(./scripts/*)
argument-hint: optional filter (e.g., 'nas-01 only', 'critical', 'all')
---

# Bug Triage Skill

Fetch open bug issues from Forgejo, prioritize by severity, present to the user for triage decisions, then act on each — either investigating, fixing via worktree + PR, deferring, or closing.

## Step 1: Fetch Open Bug Issues

```bash
./scripts/forgejo.sh issue list --label=bug
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

### Fixed-Check (recommended)

For each issue, check if it appears to already be fixed:

```bash
./scripts/issue-check-fixed.sh <issue-number>
```

This checks git history for commits referencing the issue and queries Loki for recent error activity.
Verdicts: LIKELY FIXED / STILL ACTIVE / INCONCLUSIVE.

### CI Failure Analysis

For issues related to CI failures, analyze the relevant run:

```bash
./scripts/ci-analyze.sh <run-number>
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

Create PR:

```bash
./scripts/forgejo.sh pr create \
  --title "<short description>" \
  --body "## Summary

<what this fixes and why>

Fixes #${ISSUE_NUM}

## Test plan

- [ ] \`nix build\` succeeds for affected host
- [ ] Deploy and verify fix

🤖 Generated with [Claude Code](https://claude.com/claude-code)" \
  --head "${BRANCH}" --base main
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
./scripts/forgejo.sh issue close ${ISSUE_NUM}
```

### Add a comment

```bash
./scripts/forgejo.sh issue comment ${ISSUE_NUM} --body "<comment text>

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

### Close with comment (combined)

```bash
./scripts/forgejo.sh issue close ${ISSUE_NUM} --comment "<reason>

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

## Guidelines

1. **Always confirm with the user** before closing issues or creating PRs. Never auto-close.
2. **One issue at a time** — complete the action for one issue before moving to the next.
3. **Config changes are isolated** — each fix gets its own worktree and branch. Never mix fixes for different issues.
4. **Build before committing** — always verify `nix build` succeeds before committing.
5. **Reference the issue** — use `Fixes #N` in commit messages and PR bodies so Forgejo auto-links them.
6. **Don't duplicate work** — if an issue was already fixed in an earlier commit on main, just close it as resolved.
7. **Worktree naming** — use `fix-issue-<N>` for the worktree directory and `fix/issue-<N>` for the branch name.
