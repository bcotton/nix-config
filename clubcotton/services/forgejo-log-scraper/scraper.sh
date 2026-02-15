#!/usr/bin/env bash
# Forgejo Actions log scraper for Loki
# Watches Forgejo's actions_log directory for new .log.zst files,
# decompresses them, extracts metadata, and pushes to Loki.

LOG_BASE_DIR="${LOG_BASE_DIR:?LOG_BASE_DIR must be set}"
LOKI_ENDPOINT="${LOKI_ENDPOINT:?LOKI_ENDPOINT must be set}"
STATE_DIR="${STATE_DIR:?STATE_DIR must be set}"

log() { echo "[$(date -Iseconds)] $*" >&2; }

# Convert ISO timestamp to nanosecond epoch for Loki
ts_to_nanos() {
  local ts="$1"
  # Strip sub-second precision beyond what date can handle, keep the Z
  local clean_ts
  clean_ts=$(echo "$ts" | sed -E 's/\.[0-9]+Z$/Z/')
  local epoch
  epoch=$(date -d "$clean_ts" +%s 2>/dev/null) || {
    echo "0"
    return
  }
  echo "${epoch}000000000"
}

# Regex patterns stored in variables to avoid shell parsing issues
RE_RUNNER='^[0-9T:.Z-]+[[:space:]]([^(]+)[(]version:'
RE_JOB='of job ([^,]+),'
RE_EVENT='be triggered by event: ([^[:space:]]+)'
RE_TIMESTAMP='^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})[.0-9]*Z'

process_file() {
  local filepath="$1"

  # Validate file exists and is a .log.zst
  [[ -f "$filepath" ]] || return 0
  [[ "$filepath" == *.log.zst ]] || return 0

  # Extract owner/repo from path:
  # .../actions_log/{owner}/{repo}/{shard}/{task_id}.log.zst
  local rel_path
  rel_path="${filepath#"$LOG_BASE_DIR"/}"

  local owner repo task_id_str
  owner=$(echo "$rel_path" | cut -d/ -f1)
  repo=$(echo "$rel_path" | cut -d/ -f2)
  task_id_str=$(basename "$filepath" .log.zst)

  # Build a unique key for dedup (owner/repo/task_id is globally unique)
  local state_file="${STATE_DIR}/processed"
  local dedup_key="${owner}/${repo}/${task_id_str}"

  # Check if already processed
  if [[ -f "$state_file" ]] && grep -qF "$dedup_key" "$state_file"; then
    return 0
  fi

  # Decompress
  local content
  content=$(zstd -d -c "$filepath" 2>/dev/null) || {
    log "ERROR: failed to decompress $filepath"
    return 1
  }

  if [[ -z "$content" ]]; then
    log "WARNING: empty log file $filepath, skipping"
    echo "$dedup_key" >> "$state_file"
    return 0
  fi

  # Parse first line for metadata
  # Format: "2026-02-09T15:51:33.3466208Z nix-03-runner-2(version:v7.0.0) received task 1280 of job playwright, be triggered by event: push"
  local first_line
  first_line=$(echo "$content" | head -1)

  local runner_name="" job_name="" event_type=""

  if [[ "$first_line" =~ $RE_RUNNER ]]; then
    runner_name="${BASH_REMATCH[1]}"
  fi

  if [[ "$first_line" =~ $RE_JOB ]]; then
    job_name="${BASH_REMATCH[1]}"
  fi

  if [[ "$first_line" =~ $RE_EVENT ]]; then
    event_type="${BASH_REMATCH[1]}"
  fi

  # Build Loki values array from log lines
  # Each line has a timestamp prefix like "2026-02-09T15:51:33.3466208Z ..."
  local values="[]"
  local line_count=0
  local fallback_ns
  fallback_ns="$(date +%s)000000000"

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    line_count=$((line_count + 1))

    local line_ns="$fallback_ns"
    if [[ "$line" =~ $RE_TIMESTAMP ]]; then
      local parsed_ns
      parsed_ns=$(ts_to_nanos "${BASH_REMATCH[1]}Z")
      # Add line_count as nanosecond offset to preserve ordering
      line_ns="$((parsed_ns + line_count))"
    fi

    # Use jq to properly escape the line and append to values array
    values=$(echo "$values" | jq --arg ts "$line_ns" --arg l "$line" '. + [[$ts, $l]]')
  done <<< "$content"

  if [[ "$line_count" -eq 0 ]]; then
    log "WARNING: no log lines in $filepath, skipping"
    echo "$dedup_key" >> "$state_file"
    return 0
  fi

  # Build the Loki push payload
  local payload
  payload=$(jq -n \
    --arg job "forgejo-actions" \
    --arg owner "$owner" \
    --arg repo "$repo" \
    --arg task_id "$task_id_str" \
    --arg job_name "${job_name:-unknown}" \
    --arg event "${event_type:-unknown}" \
    --arg runner "${runner_name:-unknown}" \
    --argjson values "$values" \
    '{
      streams: [{
        stream: {
          job: $job,
          owner: $owner,
          repo: $repo,
          task_id: $task_id,
          job_name: $job_name,
          event: $event,
          runner: $runner
        },
        values: $values
      }]
    }')

  # Push to Loki
  local http_code
  http_code=$(curl -s -o /dev/null -w '%{http_code}' \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$LOKI_ENDPOINT") || {
    log "ERROR: curl failed for $dedup_key"
    return 1
  }

  if [[ "$http_code" =~ ^2 ]]; then
    log "OK: pushed $dedup_key ($line_count lines, HTTP $http_code)"
    echo "$dedup_key" >> "$state_file"
  else
    log "ERROR: Loki returned HTTP $http_code for $dedup_key"
    return 1
  fi
}

# --- Main ---

log "Starting forgejo-log-scraper"
log "LOG_BASE_DIR=$LOG_BASE_DIR"
log "LOKI_ENDPOINT=$LOKI_ENDPOINT"
log "STATE_DIR=$STATE_DIR"

mkdir -p "$STATE_DIR"

# Phase 1: Backfill - process any existing unprocessed files
log "Phase 1: backfilling existing log files..."
backfill_count=0
while IFS= read -r f; do
  if process_file "$f"; then
    backfill_count=$((backfill_count + 1))
  fi
done < <(find "$LOG_BASE_DIR" -name '*.log.zst' -type f 2>/dev/null | sort)
log "Phase 1 complete: processed $backfill_count files"

# Phase 2: Watch for new files in real-time
log "Phase 2: watching for new log files..."
inotifywait -m -r --format '%w%f' -e close_write -e moved_to "$LOG_BASE_DIR" | while IFS= read -r filepath; do
  if [[ "$filepath" == *.log.zst ]]; then
    # Small delay to ensure file is fully written
    sleep 1
    process_file "$filepath" || true
  fi
done
