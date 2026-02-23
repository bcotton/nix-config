#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") <issue-number> [options]

Check whether a Forgejo issue appears to be fixed.

Checks:
  1. Git log for commits referencing #N or the affected hostname
  2. Loki for the error pattern in last 1h and 24h
  3. Issue metadata (labels, state)

Verdict: LIKELY FIXED / STILL ACTIVE / INCONCLUSIVE

Options:
  --no-loki      Skip Loki checks
  -h, --help     Show this help message
EOF
}

USE_LOKI=true
ISSUE_NUM=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-loki) USE_LOKI=false; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      if [[ -z "$ISSUE_NUM" ]]; then
        ISSUE_NUM="$1"; shift
      else
        log_error "unexpected argument: $1"; usage; exit 1
      fi
      ;;
  esac
done

if [[ -z "$ISSUE_NUM" ]]; then
  log_error "issue number required"
  usage
  exit 1
fi

check_deps curl jq git
if [[ -z "${FORGEJO_TOKEN:-}" ]]; then
  check_deps yq
fi
resolve_forgejo_config

# --- Fetch issue ---

log_info "Fetching issue #${ISSUE_NUM}..."

issue_data=$(api_get "repos/${REPO}/issues/${ISSUE_NUM}") || {
  log_error "failed to fetch issue #${ISSUE_NUM}"
  exit 1
}

title=$(echo "$issue_data" | jq -r '.title')
state=$(echo "$issue_data" | jq -r '.state')
body=$(echo "$issue_data" | jq -r '.body // ""')
labels=$(echo "$issue_data" | jq -r '[.labels[].name] | join(", ")')

echo -e "${BOLD}Issue #${ISSUE_NUM}${NC}: ${title}"
echo -e "State: ${state}  |  Labels: ${labels:-none}"
echo ""

# --- Extract hostname from title ---

# Common patterns: "hostname: description" or "hostname - description"
hostname=$(echo "$title" | grep -oP '^[a-zA-Z][-a-zA-Z0-9]*' || true)

if [[ -n "$hostname" ]]; then
  echo -e "${BOLD}Detected hostname:${NC} ${hostname}"
  # Verify it's a real host
  if [[ -x "${SCRIPT_DIR}/host-lookup.sh" ]]; then
    host_info=$("${SCRIPT_DIR}/host-lookup.sh" "$hostname" 2>/dev/null || true)
    if [[ -n "$host_info" ]]; then
      echo "  ${host_info}"
    else
      echo "  (not found in fleet — may be a service name)"
    fi
  fi
  echo ""
fi

# --- Evidence collection ---

evidence_fix=0
evidence_active=0

# Check 1: Git commits referencing this issue
echo -e "${BOLD}Git History:${NC}"

# Search for commits mentioning #N
commits_by_ref=$(git log --oneline --all -5 --grep="#${ISSUE_NUM}" 2>/dev/null || true)
if [[ -n "$commits_by_ref" ]]; then
  echo "  Commits referencing #${ISSUE_NUM}:"
  echo "$commits_by_ref" | sed 's/^/    /'
  evidence_fix=$((evidence_fix + 2))
else
  echo "  No commits reference #${ISSUE_NUM}"
fi

# Search for recent commits mentioning the hostname
if [[ -n "$hostname" ]]; then
  commits_by_host=$(git log --oneline -5 --all -- "*${hostname}*" 2>/dev/null || true)
  if [[ -z "$commits_by_host" ]]; then
    # Also try grepping commit messages
    commits_by_host=$(git log --oneline --all -5 --since="7 days ago" --grep="$hostname" 2>/dev/null || true)
  fi
  if [[ -n "$commits_by_host" ]]; then
    echo "  Recent commits mentioning ${hostname}:"
    echo "$commits_by_host" | sed 's/^/    /'
    evidence_fix=$((evidence_fix + 1))
  fi
fi
echo ""

# Check 2: Loki - is the error still occurring?
if $USE_LOKI; then
  if detect_loki 2>/dev/null; then
    echo -e "${BOLD}Loki Status:${NC}"

    # Extract error keywords from issue title/body for LogQL
    # Use hostname and key words from the title
    # Extract top 3 meaningful keywords from title for LogQL
    all_keywords=$(echo "$title" | sed -E 's/^[^:]+: //; s/[^a-zA-Z0-9 ]/ /g' | tr ' ' '\n' | \
      grep -vE '^(the|a|an|in|on|for|to|of|and|or|is|was|not|with|from|that|this|has|have|had|are|were|been|will|can|may|should|after|before|during|$)$' || true)
    error_keywords=$(echo "$all_keywords" | sed -n '1,3p' | tr '\n' '|' | sed 's/|$//')

    if [[ -n "$hostname" && -n "$error_keywords" ]]; then
      # Last 1 hour
      now=$(date +%s)
      hour_ago=$((now - 3600))
      day_ago=$((now - 86400))

      result_1h=$(curl -sG "$LOKI/loki/api/v1/query_range" \
        --data-urlencode "query={hostname=\"${hostname}\"} |~ \"(?i)(${error_keywords})\"" \
        --data-urlencode "start=${hour_ago}" \
        --data-urlencode "end=${now}" \
        --data-urlencode 'limit=5' \
        --data-urlencode 'direction=backward' 2>/dev/null || echo '{"data":{"result":[]}}')

      count_1h=$(echo "$result_1h" | jq '[.data.result[].values | length] | add // 0')

      # Last 24 hours
      result_24h=$(curl -sG "$LOKI/loki/api/v1/query_range" \
        --data-urlencode "query={hostname=\"${hostname}\"} |~ \"(?i)(${error_keywords})\"" \
        --data-urlencode "start=${day_ago}" \
        --data-urlencode "end=${now}" \
        --data-urlencode 'limit=50' \
        --data-urlencode 'direction=backward' 2>/dev/null || echo '{"data":{"result":[]}}')

      count_24h=$(echo "$result_24h" | jq '[.data.result[].values | length] | add // 0')

      echo "  Error pattern matches (${hostname} + keywords):"
      echo "    Last 1h:  ${count_1h} hits"
      echo "    Last 24h: ${count_24h} hits"

      if [[ "$count_1h" -gt 0 ]]; then
        evidence_active=$((evidence_active + 2))
        echo ""
        echo "  Recent samples:"
        echo "$result_1h" | jq -r '[.data.result[] | .stream as $s | .values[] | "    \(.[0] | tonumber / 1000000000 | strftime("%H:%M:%S")) [\($s.unit // "?")] \(.[1][:100])"] | .[:5] | .[]'
      elif [[ "$count_24h" -gt 0 ]]; then
        evidence_active=$((evidence_active + 1))
      else
        evidence_fix=$((evidence_fix + 1))
      fi
    else
      echo "  (could not extract search terms from issue title)"
    fi
    echo ""
  else
    echo -e "${YELLOW}Loki unavailable — skipping log checks${NC}"
    echo ""
  fi
fi

# --- Verdict ---

echo -e "${BOLD}━━━ Verdict ━━━${NC}"
echo ""

if [[ "$state" == "closed" ]]; then
  echo -e "${GREEN}ALREADY CLOSED${NC} — issue was previously closed"
elif [[ $evidence_fix -ge 2 && $evidence_active -eq 0 ]]; then
  echo -e "${GREEN}LIKELY FIXED${NC}"
  echo "  Evidence: commits reference the issue and no recent error activity"
elif [[ $evidence_active -ge 2 ]]; then
  echo -e "${RED}STILL ACTIVE${NC}"
  echo "  Evidence: error pattern still appearing in logs"
elif [[ $evidence_fix -gt 0 && $evidence_active -gt 0 ]]; then
  echo -e "${YELLOW}INCONCLUSIVE${NC}"
  echo "  Evidence: related commits found but errors still present"
  echo "  Recommendation: investigate whether the fix has been deployed"
elif [[ $evidence_fix -gt 0 ]]; then
  echo -e "${YELLOW}POSSIBLY FIXED${NC}"
  echo "  Evidence: related commits found, no Loki data to confirm"
else
  echo -e "${YELLOW}INCONCLUSIVE${NC}"
  echo "  Evidence: no commits found referencing this issue, no clear Loki signal"
  echo "  Recommendation: manual investigation needed"
fi
