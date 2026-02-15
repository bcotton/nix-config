#!/usr/bin/env bash
# Forgejo Actions log scraper for Loki
# Watches Forgejo's actions_log directory for new .log.zst files,
# decompresses them, extracts metadata, and pushes to Loki.

LOG_BASE_DIR="${LOG_BASE_DIR:?LOG_BASE_DIR must be set}"
LOKI_ENDPOINT="${LOKI_ENDPOINT:?LOKI_ENDPOINT must be set}"
STATE_DIR="${STATE_DIR:?STATE_DIR must be set}"

BATCH_SIZE=500

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

# Push a batch of values (JSON lines file) to Loki
# Args: values_file owner repo task_id_str job_name event_type runner_name batch_label
push_batch() {
  local values_file="$1" owner="$2" repo="$3" task_id_str="$4"
  local job_name="$5" event_type="$6" runner_name="$7" batch_label="$8"

  local values
  values=$(jq -s '.' "$values_file")

  local payload_file
  payload_file=$(mktemp)

  jq -n \
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
    }' > "$payload_file"

  local response_file
  response_file=$(mktemp)

  local http_code
  http_code=$(curl -s -o "$response_file" -w '%{http_code}' \
    -X POST \
    -H "Content-Type: application/json" \
    -d "@${payload_file}" \
    "$LOKI_ENDPOINT") || {
    log "ERROR: curl failed for $batch_label"
    rm -f "$payload_file" "$response_file"
    return 1
  }
  rm -f "$payload_file"

  if [[ "$http_code" =~ ^2 ]]; then
    log "OK: pushed $batch_label (HTTP $http_code)"
    rm -f "$response_file"
    return 0
  else
    local body
    body=$(cat "$response_file" 2>/dev/null)
    rm -f "$response_file"
    # Timestamps too old is non-retryable; return 2 to signal "skip"
    if [[ "$body" == *"timestamp too old"* ]]; then
      log "WARNING: skipping $batch_label - timestamps too old for Loki"
      return 2
    fi
    log "ERROR: Loki returned HTTP $http_code for $batch_label: $body"
    return 1
  fi
}

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

  # Create temp files upfront for cleanup
  local tmpfile values_file
  tmpfile=$(mktemp)
  values_file=$(mktemp)
  # shellcheck disable=SC2064
  trap "rm -f '$tmpfile' '$values_file'" RETURN

  # Decompress to temp file to avoid holding large content in a variable
  if ! zstd -d -c "$filepath" > "$tmpfile" 2>/dev/null; then
    log "ERROR: failed to decompress $filepath"
    return 1
  fi

  if [[ ! -s "$tmpfile" ]]; then
    log "WARNING: empty log file $filepath, skipping"
    echo "$dedup_key" >> "$state_file"
    return 0
  fi

  # Parse first line for metadata
  # Format: "2026-02-09T15:51:33.3466208Z nix-03-runner-2(version:v7.0.0) received task 1280 of job playwright, be triggered by event: push"
  local first_line
  first_line=$(head -1 "$tmpfile")

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

  # Quick age check: if the first line's timestamp is older than 6 days, skip
  # (Loki's reject_old_samples_max_age is typically ~7 days)
  if [[ "$first_line" =~ $RE_TIMESTAMP ]]; then
    local first_epoch
    first_epoch=$(date -d "${BASH_REMATCH[1]}Z" +%s 2>/dev/null) || first_epoch=0
    local cutoff_epoch
    cutoff_epoch=$(date -d '6 days ago' +%s)
    if (( first_epoch > 0 && first_epoch < cutoff_epoch )); then
      log "WARNING: skipping $dedup_key - log timestamps too old for Loki (first line: ${BASH_REMATCH[1]})"
      echo "$dedup_key" >> "$state_file"
      return 0
    fi
  fi

  # Build Loki values as JSON lines in a temp file (one [ts, line] per line)
  # This avoids accumulating a large JSON array in a shell variable
  local line_count=0
  local batch_count=0
  local fallback_ns
  fallback_ns="$(date +%s)000000000"
  local all_ok=true

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

    # Write each value pair as a JSON line (small, constant-size jq args)
    jq -nc --arg ts "$line_ns" --arg l "$line" '[$ts, $l]' >> "$values_file"

    # Send batch when we hit the limit
    if (( line_count % BATCH_SIZE == 0 )); then
      batch_count=$((batch_count + 1))
      push_batch "$values_file" "$owner" "$repo" "$task_id_str" \
           "$job_name" "$event_type" "$runner_name" \
           "${dedup_key} (batch ${batch_count})"
      local rc=$?
      if [[ $rc -eq 2 ]]; then
        # Timestamps too old - skip entire file
        echo "$dedup_key" >> "$state_file"
        return 0
      elif [[ $rc -ne 0 ]]; then
        all_ok=false
      fi
      : > "$values_file"  # truncate for next batch
    fi
  done < "$tmpfile"

  if [[ "$line_count" -eq 0 ]]; then
    log "WARNING: no log lines in $filepath, skipping"
    echo "$dedup_key" >> "$state_file"
    return 0
  fi

  # Send remaining lines
  if [[ -s "$values_file" ]]; then
    batch_count=$((batch_count + 1))
    local batch_label="$dedup_key"
    if (( batch_count > 1 )); then
      batch_label="${dedup_key} (batch ${batch_count})"
    fi
    push_batch "$values_file" "$owner" "$repo" "$task_id_str" \
         "$job_name" "$event_type" "$runner_name" "$batch_label"
    local rc=$?
    if [[ $rc -eq 2 ]]; then
      echo "$dedup_key" >> "$state_file"
      return 0
    elif [[ $rc -ne 0 ]]; then
      all_ok=false
    fi
  fi

  if $all_ok; then
    log "OK: completed $dedup_key ($line_count lines, $batch_count batch(es))"
    echo "$dedup_key" >> "$state_file"
  else
    log "ERROR: some batches failed for $dedup_key"
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
