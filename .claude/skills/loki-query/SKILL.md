---
name: loki-query
description: Query infrastructure logs from Loki. Use when asked to check logs, query loki, investigate errors, debug services, find log entries, analyze what happened on a host, or search for patterns in logs.
allowed-tools: Bash(curl *), Bash(jq *), Bash(date *)
argument-hint: describe what to find (e.g., 'errors on nas-01 in the last hour')
---

# Loki Log Query Skill

Query the Loki log aggregation service to investigate issues, debug services, and analyze log patterns across the NixOS infrastructure.

## Loki Endpoint

- **Primary:** `https://loki.bobtail-clownfish.ts.net` (Tailscale HTTPS -- works from anywhere on the tailnet)
- **Fallback:** `http://nas-01.lan:3100` (LAN only)
- **Auth:** None (auth disabled)
- **Retention:** 30 days

**Always detect the working endpoint before querying.** Try Tailscale first, fall back to LAN:

```bash
LOKI=$(curl -sf --max-time 3 https://loki.bobtail-clownfish.ts.net/ready >/dev/null 2>&1 \
  && echo "https://loki.bobtail-clownfish.ts.net" \
  || echo "http://nas-01.lan:3100")
```

Then use `$LOKI` as the base URL for all subsequent queries in the same shell. If both fail, tell the user Loki appears down and suggest checking `systemctl status loki` on nas-01.

## Available Labels (live)

!`(curl -sf --max-time 3 https://loki.bobtail-clownfish.ts.net/loki/api/v1/labels 2>/dev/null || curl -sf --max-time 3 http://nas-01.lan:3100/loki/api/v1/labels 2>/dev/null) | jq -r '.data[]' 2>/dev/null || echo "(Loki unreachable - labels unavailable)"`

## Current Hosts Sending Logs

!`(curl -sf --max-time 3 https://loki.bobtail-clownfish.ts.net/loki/api/v1/label/hostname/values 2>/dev/null || curl -sf --max-time 3 http://nas-01.lan:3100/loki/api/v1/label/hostname/values 2>/dev/null) | jq -r '.data[]' 2>/dev/null || echo "(Loki unreachable - hosts unavailable)"`

## Current Job Names

!`(curl -sf --max-time 3 https://loki.bobtail-clownfish.ts.net/loki/api/v1/label/job/values 2>/dev/null || curl -sf --max-time 3 http://nas-01.lan:3100/loki/api/v1/label/job/values 2>/dev/null) | jq -r '.data[]' 2>/dev/null || echo "(Loki unreachable - jobs unavailable)"`

## Label Reference

| Label | Description | Example Values |
|-------|-------------|----------------|
| `job` | Log source type | `systemd-journal`, `forgejo-actions`, `openclaw` |
| `hostname` | Machine that generated the log | `nas-01`, `nix-01`, `dns-01` |
| `unit` | Systemd unit name | `sshd.service`, `jellyfin.service`, `postgresql.service` |
| `user_unit` | Systemd user unit name | User-level services |
| `syslog_identifier` | Syslog identifier | Program name that sent the log |
| `transport` | Journal transport method | `stdout`, `journal`, `kernel` |
| `priority` | Syslog priority keyword | `emerg`, `alert`, `crit`, `err`, `warning`, `notice`, `info`, `debug` |
| `level` | Alias for priority | Same as priority |

### Priority Mapping

Users say "error" but the label value is `err`. Map common terms:

| User says | LogQL filter |
|-----------|-------------|
| "errors" | `{priority="err"}` or `{priority=~"err\|crit\|alert\|emerg"}` |
| "warnings" | `{priority="warning"}` |
| "critical" | `{priority=~"crit\|alert\|emerg"}` |

## Loki HTTP API

**First, detect the endpoint** (run once per session):

```bash
LOKI=$(curl -sf --max-time 3 https://loki.bobtail-clownfish.ts.net/ready >/dev/null 2>&1 \
  && echo "https://loki.bobtail-clownfish.ts.net" \
  || echo "http://nas-01.lan:3100")
echo "Using Loki at: $LOKI"
```

**Always use `-sG` with `--data-urlencode` for queries.** LogQL contains `{}`, `|`, `=` which break without URL encoding.

### Query Range (most common)

```bash
curl -sG "$LOKI/loki/api/v1/query_range" \
  --data-urlencode 'query={hostname="nas-01", job="systemd-journal"} |= "error"' \
  --data-urlencode "start=$(date -d '1 hour ago' +%s)" \
  --data-urlencode "end=$(date +%s)" \
  --data-urlencode 'limit=100' \
  --data-urlencode 'direction=backward' | jq .
```

### Instant Query (for metric queries)

```bash
curl -sG "$LOKI/loki/api/v1/query" \
  --data-urlencode 'query=sum by (hostname) (count_over_time({job="systemd-journal"} |= "error" [1h]))' \
  --data-urlencode "time=$(date +%s)" | jq .
```

### List Labels

```bash
curl -s "$LOKI/loki/api/v1/labels" | jq .
```

### List Label Values

```bash
curl -s "$LOKI/loki/api/v1/label/hostname/values" | jq .
curl -s "$LOKI/loki/api/v1/label/unit/values" | jq .
```

### Get Series

```bash
curl -sG "$LOKI/loki/api/v1/series" \
  --data-urlencode 'match[]={hostname="nas-01"}' | jq .
```

## Formatting Results

Parse log results into readable output:

```bash
# For log queries -- extract timestamp, hostname, unit, and log line
| jq -r '.data.result[] | .stream as $s | .values[] | "\(.[0] | tonumber / 1000000000 | strftime("%Y-%m-%d %H:%M:%S")) [\($s.hostname // "?")] [\($s.unit // $s.job // "?")] \(.[1])"'
```

```bash
# For metric queries -- extract label values and counts
| jq -r '.data.result[] | "\(.metric | to_entries | map("\(.key)=\(.value)") | join(", ")): \(.value[1])"'
```

Default to `limit=100` and `direction=backward` (newest first). Increase limit only if the user asks.

## LogQL Syntax

### Stream Selectors

```logql
{hostname="nas-01"}                          # exact match
{hostname!="nas-01"}                         # not equal
{hostname=~"nix-0[1-4]"}                    # regex match
{hostname!~"dns.*"}                          # negative regex
{hostname="nas-01", unit="sshd.service"}     # multiple labels (AND)
```

### Line Filters

Applied after stream selector, left to right:

```logql
|= "text"       # line contains string (case-sensitive)
!= "text"       # line does NOT contain string
|~ "regex"      # line matches regex
!~ "regex"      # line does NOT match regex
```

**Most journal logs are plain text, not JSON.** Use `|=` line filters as the primary filter for systemd-journal logs. The `| json` parser only works on structured JSON log lines.

### Parsers (for structured logs only)

```logql
| json                         # parse JSON fields
| logfmt                       # parse logfmt fields
| pattern "<_> level=<level>"  # extract by pattern
| regexp "(?P<ip>\\d+\\.\\d+\\.\\d+\\.\\d+)"  # regex extraction
```

### Label Filters (after parsing)

```logql
| level = "error"
| status >= 400
| duration > 10s
| message =~ "timeout|refused"
```

### Metric Queries

```logql
count_over_time({query}[range])                           # count log lines
rate({query}[range])                                      # lines per second
bytes_over_time({query}[range])                           # total bytes
sum by (label) (count_over_time({query}[range]))          # count grouped by label
topk(10, sum by (unit) (count_over_time({query}[range]))) # top N by count
```

## Common Query Patterns

### Errors on a specific host

```logql
{hostname="nas-01", job="systemd-journal"} |= "error"
```

### Errors across all hosts (use priority label for precision)

```logql
{job="systemd-journal", priority=~"err|crit|alert|emerg"}
```

### Query a specific service

```logql
{hostname="nas-01", unit="jellyfin.service"}
```

### NixOS auto-upgrade results

```logql
{unit="nixos-upgrade.service"}
```

### Service crash/restart detection

```logql
{job="systemd-journal"} |~ "Started |Stopped |Failed |Main process exited"
```

### OOM kills

```logql
{job="systemd-journal"} |~ "Out of memory|oom-kill|Killed process"
```

### Disk / ZFS issues

```logql
{job="systemd-journal", hostname="nas-01"} |~ "zfs|zpool" |~ "error|fault|degraded|FAULTED"
```

### Network issues

```logql
{job="systemd-journal"} |~ "connection refused|timeout|unreachable"
```

### SSH authentication failures

```logql
{unit="sshd.service"} |~ "Failed|Invalid user"
```

### Forgejo CI/CD logs

```logql
{job="forgejo-actions"}
```

### OpenClaw logs (nix-02)

```logql
{job="openclaw", hostname="nix-02"}
```

### Count errors per host (last hour)

```logql
sum by (hostname) (count_over_time({job="systemd-journal", priority=~"err|crit|alert|emerg"}[1h]))
```

### Top 10 noisiest services on a host

```logql
topk(10, sum by (unit) (count_over_time({hostname="nas-01", job="systemd-journal"}[1h])))
```

## Timestamp Helpers

```bash
date +%s                            # now (epoch seconds)
date -d '1 hour ago' +%s           # 1 hour ago
date -d '6 hours ago' +%s          # 6 hours ago
date -d '24 hours ago' +%s         # 24 hours ago
date -d '7 days ago' +%s           # 7 days ago
date -d '2026-02-20 03:00:00' +%s  # specific time
```

Default time range is **1 hour**. If no results, expand to 6h or 24h before reporting empty.

## Error Handling

- **Loki unreachable:** Check `/ready`. If it fails, tell the user Loki is down on nas-01.
- **Empty results:** First verify the stream selector matches anything (query without line filters). Then widen the time range. Check that the unit/hostname label values are correct by querying `/loki/api/v1/label/{name}/values`.
- **Query timeout:** Narrow the query -- add `hostname`, reduce time range, add line filters.
- **Parse errors:** Check LogQL syntax. Common mistakes: missing quotes around label values, unescaped regex characters, using `| json` on plain text logs.

## Workflow

When the user asks to check logs:

1. Detect endpoint: set `$LOKI` using the auto-detect snippet above
2. Build the LogQL query from the user's intent
3. Run the query with `curl -sG "$LOKI/..."` and `--data-urlencode`
4. Format output with `jq` for readability
5. Summarize findings -- highlight errors, patterns, or anomalies
6. If empty, widen the search and try again
