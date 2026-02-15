#!/usr/bin/env bash
# Forgejo Actions log scraper for Loki
# Watches Forgejo's actions_log directory for new .log.zst files,
# decompresses them, extracts metadata, and pushes to Loki.

LOG_BASE_DIR="${LOG_BASE_DIR:?LOG_BASE_DIR must be set}"
LOKI_ENDPOINT="${LOKI_ENDPOINT:?LOKI_ENDPOINT must be set}"
STATE_DIR="${STATE_DIR:?STATE_DIR must be set}"

BATCH_SIZE="${BATCH_SIZE:-500}"
MAX_PARALLEL="${MAX_PARALLEL:-4}"
DB_FILE="${STATE_DIR}/processed.db"

log() { echo "[$(date -Iseconds)] $*" >&2; }

# --- SQLite state tracking ---


# Run a SQL statement with busy timeout set on every connection
sql() {
  sqlite3 -cmd '.timeout 5000' "$DB_FILE" "$1"
}

init_db() {
  sql "CREATE TABLE IF NOT EXISTS processed (dedup_key TEXT PRIMARY KEY NOT NULL);"
  sql "PRAGMA journal_mode=WAL;" >/dev/null
}

is_processed() {
  local key="$1"
  local count
  count=$(sql "SELECT COUNT(*) FROM processed WHERE dedup_key='${key//\'/\'\'}';")
  [[ "$count" -gt 0 ]]
}

mark_processed() {
  local key="$1"
  sql "INSERT OR IGNORE INTO processed (dedup_key) VALUES ('${key//\'/\'\'}');"
}

# --- Regex patterns ---

RE_RUNNER='^[0-9T:.Z-]+[[:space:]]([^(]+)[(]version:'
RE_JOB='of job ([^,]+),'
RE_EVENT='be triggered by event: ([^[:space:]]+)'
RE_TIMESTAMP='^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})[.0-9]*Z'

# --- Push a batch of values (JSON lines file) to Loki ---

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

# --- Process a single log file ---

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

  local dedup_key="${owner}/${repo}/${task_id_str}"

  # Check if already processed
  if is_processed "$dedup_key"; then
    return 0
  fi

  # Create temp files and batch directory for cleanup
  local tmpfile batch_dir
  tmpfile=$(mktemp)
  batch_dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -f '$tmpfile'; rm -rf '$batch_dir'" RETURN

  # Decompress to temp file
  if ! zstd -d -c "$filepath" > "$tmpfile" 2>/dev/null; then
    log "ERROR: failed to decompress $filepath"
    return 1
  fi

  if [[ ! -s "$tmpfile" ]]; then
    log "WARNING: empty log file $filepath, skipping"
    mark_processed "$dedup_key"
    return 0
  fi

  # Parse first line for metadata
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
  if [[ "$first_line" =~ $RE_TIMESTAMP ]]; then
    local first_epoch
    first_epoch=$(date -d "${BASH_REMATCH[1]}Z" +%s 2>/dev/null) || first_epoch=0
    local cutoff_epoch
    cutoff_epoch=$(date -d '6 days ago' +%s)
    if (( first_epoch > 0 && first_epoch < cutoff_epoch )); then
      log "WARNING: skipping $dedup_key - log timestamps too old for Loki (first line: ${BASH_REMATCH[1]})"
      mark_processed "$dedup_key"
      return 0
    fi
  fi

  # Use gawk to process all log lines in a single invocation:
  # - Extract timestamps via mktime (no per-line date subprocess)
  # - JSON-escape each line
  # - Write batch files directly (one per BATCH_SIZE lines)
  # - Output metadata (line_count batch_count) to a meta file
  local fallback_ns
  fallback_ns="$(date +%s)000000000"

  TZ=UTC gawk \
    -v fallback_ns="$fallback_ns" \
    -v batch_size="$BATCH_SIZE" \
    -v batch_prefix="${batch_dir}/batch_" \
    '
    function json_escape(s) {
      gsub(/\\/, "\\\\", s)
      gsub(/"/, "\\\"", s)
      gsub(/\t/, "\\t", s)
      gsub(/\r/, "\\r", s)
      gsub(/\n/, "\\n", s)
      gsub(/\x08/, "\\b", s)
      gsub(/\x0c/, "\\f", s)
      # Strip remaining control characters (U+0000-U+001F)
      gsub(/[\x00-\x07\x0b\x0e-\x1f]/, "", s)
      return s
    }

    BEGIN {
      line_count = 0
      batch_num = 1
      batch_file = batch_prefix batch_num
      re_ts = "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}"
    }

    /^$/ { next }

    {
      line_count++
      line_ns = fallback_ns + 0 + line_count

      if (match($0, re_ts)) {
        ts_str = substr($0, RSTART, RLENGTH)
        # Parse "YYYY-MM-DDTHH:MM:SS" into mktime format "YYYY MM DD HH MM SS"
        split(ts_str, a, /[-T:]/)
        epoch = mktime(a[1] " " a[2] " " a[3] " " a[4] " " a[5] " " a[6])
        if (epoch > 0) {
          line_ns = epoch "000000000" + 0 + line_count
        }
      }

      escaped = json_escape($0)
      print "[\"" line_ns "\",\"" escaped "\"]" > batch_file

      if (line_count % batch_size == 0) {
        close(batch_file)
        batch_num++
        batch_file = batch_prefix batch_num
      }
    }

    END {
      if (line_count > 0 && line_count % batch_size != 0) close(batch_file)
      print line_count " " batch_num > (batch_prefix "meta")
      close(batch_prefix "meta")
    }
    ' "$tmpfile"

  # Read metadata from gawk output
  local line_count batch_count
  if [[ ! -f "${batch_dir}/batch_meta" ]]; then
    log "WARNING: no log lines in $filepath, skipping"
    mark_processed "$dedup_key"
    return 0
  fi
  read -r line_count batch_count < "${batch_dir}/batch_meta"

  if [[ "$line_count" -eq 0 ]]; then
    log "WARNING: no log lines in $filepath, skipping"
    mark_processed "$dedup_key"
    return 0
  fi

  # Send batches to Loki
  local all_ok=true
  local i
  for (( i=1; i<=batch_count; i++ )); do
    local batch_file="${batch_dir}/batch_${i}"
    [[ -s "$batch_file" ]] || continue

    local batch_label="$dedup_key"
    if (( batch_count > 1 )); then
      batch_label="${dedup_key} (batch ${i}/${batch_count})"
    fi

    push_batch "$batch_file" "$owner" "$repo" "$task_id_str" \
         "$job_name" "$event_type" "$runner_name" "$batch_label"
    local rc=$?
    if [[ $rc -eq 2 ]]; then
      # Timestamps too old - skip entire file
      mark_processed "$dedup_key"
      return 0
    elif [[ $rc -ne 0 ]]; then
      all_ok=false
    fi
  done

  if $all_ok; then
    log "OK: completed $dedup_key ($line_count lines, $batch_count batch(es))"
    mark_processed "$dedup_key"
  else
    log "ERROR: some batches failed for $dedup_key"
    return 1
  fi
}

# --- Single-file mode for parallel backfill ---

if [[ "${1:-}" == "--process-file" ]]; then
  process_file "$2"
  exit $?
fi

# --- Main ---

log "Starting forgejo-log-scraper"
log "LOG_BASE_DIR=$LOG_BASE_DIR"
log "LOKI_ENDPOINT=$LOKI_ENDPOINT"
log "STATE_DIR=$STATE_DIR"

mkdir -p "$STATE_DIR"
init_db

# Phase 1: Backfill - process existing unprocessed files in parallel
log "Phase 1: backfilling existing log files (${MAX_PARALLEL} workers)..."

find "$LOG_BASE_DIR" -name '*.log.zst' -type f 2>/dev/null | sort | \
  xargs -P "$MAX_PARALLEL" -I {} "$0" --process-file {} || true

backfill_total=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM processed;")
log "Phase 1 complete: $backfill_total total files in processed state"

# Phase 2: Watch for new files in real-time
log "Phase 2: watching for new log files..."
inotifywait -m -r --format '%w%f' -e close_write -e moved_to "$LOG_BASE_DIR" | while IFS= read -r filepath; do
  if [[ "$filepath" == *.log.zst ]]; then
    # Small delay to ensure file is fully written
    sleep 1
    process_file "$filepath" || true
  fi
done
