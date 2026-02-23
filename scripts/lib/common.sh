#!/usr/bin/env bash
# Shared library for infrastructure tooling scripts.
# Source this file; do not execute directly.
#
# Provides: colors, logging, dependency checking, Forgejo API helpers,
#           Loki endpoint detection, and time formatting utilities.

# Guard against direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "error: common.sh is a library — source it, don't execute it" >&2
  exit 1
fi

# ---------- Colors (disabled when not a terminal) ----------

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

# ---------- Logging ----------

log_error() { echo -e "${RED}error:${NC} $*" >&2; }
log_info()  { echo -e "${BLUE}::${NC} $*" >&2; }

# ---------- Dependency checks ----------

# Usage: check_deps curl jq yq
check_deps() {
  local missing=()
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "missing required tools: ${missing[*]}"
    exit 1
  fi
}

# ---------- Forgejo config resolution ----------

TEA_CONFIG="${HOME}/.config/tea/config.yml"

resolve_forgejo_config() {
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
  BASE_URL="${BASE_URL%/}"

  if [[ -n "${FORGEJO_REPO:-}" ]]; then
    REPO="$FORGEJO_REPO"
  else
    local remote
    remote=$(git remote get-url origin 2>/dev/null || true)
    if [[ -n "$remote" ]]; then
      REPO=$(echo "$remote" | sed -E 's#^(ssh://[^/]+/|https?://[^/]+/|[^@]+@[^:]+:)##; s/\.git$//')
    else
      log_error "could not detect repo from git remote; set FORGEJO_REPO"
      exit 1
    fi
  fi
}

# ---------- API helpers ----------

api_get() {
  local endpoint="$1"
  curl -sf -H "Authorization: token $TOKEN" "${BASE_URL}/api/v1/${endpoint}"
}

api_post() {
  local endpoint="$1"
  local data="$2"
  curl -sf -X POST \
    -H "Authorization: token $TOKEN" \
    -H "Content-Type: application/json" \
    "${BASE_URL}/api/v1/${endpoint}" \
    -d "$data"
}

api_patch() {
  local endpoint="$1"
  local data="$2"
  curl -sf -X PATCH \
    -H "Authorization: token $TOKEN" \
    -H "Content-Type: application/json" \
    "${BASE_URL}/api/v1/${endpoint}" \
    -d "$data"
}

# ---------- Loki endpoint detection ----------

detect_loki() {
  if curl -sf --max-time 3 https://loki.bobtail-clownfish.ts.net/ready >/dev/null 2>&1; then
    LOKI="https://loki.bobtail-clownfish.ts.net"
  elif curl -sf --max-time 3 http://nas-01.lan:3100/ready >/dev/null 2>&1; then
    LOKI="http://nas-01.lan:3100"
  else
    log_error "Loki appears to be down (both Tailscale and LAN endpoints unreachable)"
    return 1
  fi
}

# ---------- Label resolution ----------

# Usage: resolve_label_id "bug"  =>  sets LABEL_ID
resolve_label_id() {
  local label_name="$1"
  LABEL_ID=$(api_get "repos/${REPO}/labels?limit=50" \
    | jq -r --arg name "$label_name" '.[] | select(.name == $name) | .id')
  if [[ -z "$LABEL_ID" ]]; then
    log_error "label '$label_name' not found"
    return 1
  fi
}

# ---------- Formatting helpers ----------

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
