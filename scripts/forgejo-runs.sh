#!/usr/bin/env bash
set -euo pipefail

TEA_CONFIG="${HOME}/.config/tea/config.yml"

# Colors (disabled when not a terminal)
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

log_error() { echo -e "${RED}error:${NC} $*" >&2; }
log_info()  { echo -e "${BLUE}::${NC} $*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [command] [options]

Commands:
  list              List recent workflow runs (default)
  show <run>        Show details of a specific run number
  logs <run> [job]  Show logs for a run (job index defaults to 0)

Options:
  -n, --limit NUM      Number of runs to show (default: 10)
  -s, --status STATUS  Filter by status (success, failure, running, cancelled)
  -b, --branch BRANCH  Filter by branch name
  -j, --jobs           Show individual jobs instead of grouped runs
  -h, --help           Show this help message

Environment variables:
  FORGEJO_TOKEN   API token (overrides tea config)
  FORGEJO_URL     Forgejo instance URL (overrides tea config)
  FORGEJO_REPO    Repository as owner/repo (overrides git remote detection)

Token is read from tea CLI config at ${TEA_CONFIG} by default.
EOF
}

# --- Dependency checks ---

check_deps() {
  local missing=()
  for cmd in curl jq; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ -z "${FORGEJO_TOKEN:-}" ]] && ! command -v yq &>/dev/null; then
    missing+=("yq (needed to read tea config)")
  fi
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "missing required tools: ${missing[*]}"
    exit 1
  fi
}

# --- Token & URL resolution ---

resolve_config() {
  if [[ -n "${FORGEJO_TOKEN:-}" ]]; then
    TOKEN="$FORGEJO_TOKEN"
  elif [[ -f "$TEA_CONFIG" ]]; then
    TOKEN=$(yq -r '.logins[0].token' "$TEA_CONFIG")
    if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
      log_error "could not extract token from $TEA_CONFIG"
      log_error "run 'tea login add' or set FORGEJO_TOKEN"
      exit 1
    fi
  else
    log_error "no FORGEJO_TOKEN set and tea config not found at $TEA_CONFIG"
    log_error "either: tea login add  OR  export FORGEJO_TOKEN=..."
    exit 1
  fi

  if [[ -n "${FORGEJO_URL:-}" ]]; then
    BASE_URL="$FORGEJO_URL"
  elif [[ -f "$TEA_CONFIG" ]]; then
    BASE_URL=$(yq -r '.logins[0].url' "$TEA_CONFIG")
  else
    log_error "no FORGEJO_URL set and tea config not found"
    exit 1
  fi
  # strip trailing slash
  BASE_URL="${BASE_URL%/}"

  if [[ -n "${FORGEJO_REPO:-}" ]]; then
    REPO="$FORGEJO_REPO"
  else
    local remote
    remote=$(git remote get-url origin 2>/dev/null || true)
    if [[ -n "$remote" ]]; then
      # Handle ssh://user@host:port/owner/repo.git and git@host:owner/repo.git
      REPO=$(echo "$remote" | sed -E 's#^(ssh://[^/]+/|https?://[^/]+/|[^@]+@[^:]+:)##; s/\.git$//')
    else
      log_error "could not detect repo from git remote; set FORGEJO_REPO"
      exit 1
    fi
  fi
}

# --- API helpers ---

api_get() {
  local endpoint="$1"
  local response
  response=$(curl -sf -H "Authorization: token $TOKEN" "${BASE_URL}/api/v1/${endpoint}")
  echo "$response"
}

status_color() {
  case "$1" in
    success)   echo -n "${GREEN}" ;;
    failure)   echo -n "${RED}" ;;
    running)   echo -n "${BLUE}" ;;
    cancelled) echo -n "${YELLOW}" ;;
    *)         echo -n "" ;;
  esac
}

relative_time() {
  local timestamp="$1"
  local then_epoch now_epoch diff
  then_epoch=$(date -d "$timestamp" +%s 2>/dev/null) || return
  now_epoch=$(date +%s)
  diff=$((now_epoch - then_epoch))
  if (( diff < 60 )); then echo "${diff}s ago"
  elif (( diff < 3600 )); then echo "$((diff / 60))m ago"
  elif (( diff < 86400 )); then echo "$((diff / 3600))h ago"
  else echo "$((diff / 86400))d ago"
  fi
}

# --- Commands ---

cmd_list() {
  local limit="$1" status_filter="$2" branch_filter="$3" show_jobs="$4"
  # Over-fetch to account for client-side filtering and grouping
  local fetch_limit=$((limit * 15))
  (( fetch_limit < 50 )) && fetch_limit=50

  local data
  data=$(api_get "repos/${REPO}/actions/tasks?limit=${fetch_limit}") || {
    log_error "API request failed"
    exit 1
  }

  if [[ "$show_jobs" == "true" ]]; then
    # Flat mode: one row per job
    local jq_filter='.workflow_runs'
    [[ -n "$status_filter" ]] && jq_filter+=" | map(select(.status == \"$status_filter\"))"
    [[ -n "$branch_filter" ]] && jq_filter+=" | map(select(.head_branch == \"$branch_filter\"))"
    jq_filter+=" | .[:${limit}]"
    jq_filter+=' | .[] | [(.run_number|tostring), .status, .head_branch, .event, .name, .display_title, .created_at] | @tsv'

    local header
    printf "${BOLD}%-7s %-12s %-15s %-6s %-25s %-40s %s${NC}\n" "RUN" "STATUS" "BRANCH" "EVENT" "JOB" "TITLE" "AGE"

    echo "$data" | jq -r "$jq_filter" | while IFS=$'\t' read -r run status branch event name title created; do
      local color age
      color=$(status_color "$status")
      age=$(relative_time "$created")
      printf "%-7s ${color}%-12s${NC} %-15s %-6s %-25s %-40s %s\n" \
        "#${run}" "$status" "$branch" "$event" "${name:0:24}" "${title:0:39}" "$age"
    done
  else
    # Grouped mode: one row per run_number
    local jq_expr
    jq_expr='[.workflow_runs | group_by(.run_number) | .[] | {
      run_number: .[0].run_number,
      branch: .[0].head_branch,
      event: .[0].event,
      title: .[0].display_title,
      created: .[0].created_at,
      jobs: ([.[] | .name] | join(", ")),
      job_count: (. | length),
      status: (if any(.[]; .status == "failure") then "failure"
               elif any(.[]; .status == "running") then "running"
               elif any(.[]; .status == "cancelled") then "cancelled"
               else "success" end)
    }] | sort_by(.run_number) | reverse'

    [[ -n "$status_filter" ]] && jq_expr+=" | map(select(.status == \"$status_filter\"))"
    [[ -n "$branch_filter" ]] && jq_expr+=" | map(select(.branch == \"$branch_filter\"))"
    jq_expr+=" | .[:${limit}]"
    jq_expr+=' | .[] | [(.run_number|tostring), .status, .branch, .event, .title, .jobs, .created] | @tsv'

    printf "${BOLD}%-7s %-12s %-15s %-6s %-40s %-30s %s${NC}\n" "RUN" "STATUS" "BRANCH" "EVENT" "TITLE" "JOBS" "AGE"

    echo "$data" | jq -r "$jq_expr" | while IFS=$'\t' read -r run status branch event title jobs created; do
      local color age
      color=$(status_color "$status")
      age=$(relative_time "$created")
      printf "%-7s ${color}%-12s${NC} %-15s %-6s %-40s %-30s %s\n" \
        "#${run}" "$status" "$branch" "$event" "${title:0:39}" "${jobs:0:29}" "$age"
    done
  fi
}

cmd_show() {
  local run_number="$1"
  local data
  data=$(api_get "repos/${REPO}/actions/tasks?limit=50") || {
    log_error "API request failed"
    exit 1
  }

  local run_data
  run_data=$(echo "$data" | jq --argjson rn "$run_number" '[.workflow_runs[] | select(.run_number == $rn)]')
  local count
  count=$(echo "$run_data" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    log_error "run #${run_number} not found in recent runs"
    exit 1
  fi

  local title branch event sha created url
  title=$(echo "$run_data" | jq -r '.[0].display_title')
  branch=$(echo "$run_data" | jq -r '.[0].head_branch')
  event=$(echo "$run_data" | jq -r '.[0].event')
  sha=$(echo "$run_data" | jq -r '.[0].head_sha[:7]')
  created=$(echo "$run_data" | jq -r '.[0].created_at')
  url=$(echo "$run_data" | jq -r '.[0].url')

  echo -e "${BOLD}Run #${run_number}${NC} - ${title}"
  echo -e "Branch: ${branch}  |  Event: ${event}  |  SHA: ${sha}"
  echo -e "Created: ${created}  ($(relative_time "$created"))"
  echo -e "URL: ${url}"
  echo ""
  echo -e "${BOLD}Jobs:${NC}"

  echo "$run_data" | jq -r '.[] | [.name, .status, .created_at, .updated_at] | @tsv' | \
  while IFS=$'\t' read -r name status created updated; do
    local color idx_display
    color=$(status_color "$status")
    echo -e "  ${color}${status}${NC}  ${name}"
  done
}

cmd_logs() {
  local run_number="$1"
  local job_index="${2:-0}"

  # Logs are served at the web UI path
  local url="${BASE_URL}/${REPO}/actions/runs/${run_number}/jobs/${job_index}/logs"
  log_info "fetching logs from ${url}"

  curl -sf -H "Authorization: token $TOKEN" "$url" || {
    log_error "failed to fetch logs (run #${run_number}, job ${job_index})"
    log_error "check the run exists: $(basename "$0") show ${run_number}"
    exit 1
  }
}

# --- Argument parsing ---

COMMAND="list"
LIMIT=10
STATUS_FILTER=""
BRANCH_FILTER=""
SHOW_JOBS=false
RUN_NUMBER=""
JOB_INDEX=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    list)  COMMAND="list"; shift ;;
    show)  COMMAND="show"; shift ;;
    logs)  COMMAND="logs"; shift ;;
    -n|--limit)  LIMIT="$2"; shift 2 ;;
    -s|--status) STATUS_FILTER="$2"; shift 2 ;;
    -b|--branch) BRANCH_FILTER="$2"; shift 2 ;;
    -j|--jobs)   SHOW_JOBS=true; shift ;;
    -h|--help)   usage; exit 0 ;;
    *)
      if [[ "$COMMAND" == "show" || "$COMMAND" == "logs" ]] && [[ -z "$RUN_NUMBER" ]]; then
        RUN_NUMBER="$1"; shift
      elif [[ "$COMMAND" == "logs" ]] && [[ -n "$RUN_NUMBER" ]] && [[ -z "$JOB_INDEX" ]]; then
        JOB_INDEX="$1"; shift
      else
        log_error "unknown option: $1"
        usage
        exit 1
      fi
      ;;
  esac
done

# --- Main ---

check_deps
resolve_config

case "$COMMAND" in
  list)
    cmd_list "$LIMIT" "$STATUS_FILTER" "$BRANCH_FILTER" "$SHOW_JOBS"
    ;;
  show)
    if [[ -z "$RUN_NUMBER" ]]; then
      log_error "show requires a run number"
      usage
      exit 1
    fi
    cmd_show "$RUN_NUMBER"
    ;;
  logs)
    if [[ -z "$RUN_NUMBER" ]]; then
      log_error "logs requires a run number"
      usage
      exit 1
    fi
    cmd_logs "$RUN_NUMBER" "${JOB_INDEX:-0}"
    ;;
esac
