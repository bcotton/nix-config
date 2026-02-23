#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Forgejo issue and PR management.

Commands:
  issue list   [--label=<name>] [--state=<open|closed>] [--limit=N]
  issue create --title "..." --body "..." [--label <name>]
  issue close  <N> [--comment "..."]
  issue comment <N> --body "..."
  pr create    --title "..." --body "..." --head <branch> [--base main]

Options:
  -h, --help   Show this help message
EOF
}

# --- Issue commands ---

cmd_issue_list() {
  local label="" state="open" limit=50
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --label=*) label="${1#--label=}"; shift ;;
      --label)   label="$2"; shift 2 ;;
      --state=*) state="${1#--state=}"; shift ;;
      --state)   state="$2"; shift 2 ;;
      --limit=*) limit="${1#--limit=}"; shift ;;
      --limit)   limit="$2"; shift 2 ;;
      *) log_error "unknown option: $1"; exit 1 ;;
    esac
  done

  local endpoint="repos/${REPO}/issues?state=${state}&limit=${limit}&sort=created&direction=desc&type=issues"
  if [[ -n "$label" ]]; then
    endpoint+="&labels=${label}"
  fi

  local data
  data=$(api_get "$endpoint") || {
    log_error "API request failed"
    exit 1
  }

  echo "$data" | jq -r '.[] | "#\(.number)\t\(.title)\t\(.created_at[:10])\t\([ .labels[].name ] | join(","))"' | \
    column -t -s $'\t'
}

cmd_issue_create() {
  local title="" body="" label=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title=*) title="${1#--title=}"; shift ;;
      --title)   title="$2"; shift 2 ;;
      --body=*)  body="${1#--body=}"; shift ;;
      --body)    body="$2"; shift 2 ;;
      --label=*) label="${1#--label=}"; shift ;;
      --label)   label="$2"; shift 2 ;;
      *) log_error "unknown option: $1"; exit 1 ;;
    esac
  done

  if [[ -z "$title" ]]; then
    log_error "issue create requires --title"
    exit 1
  fi

  local payload
  if [[ -n "$label" ]]; then
    resolve_label_id "$label"
    payload=$(jq -n --arg title "$title" --arg body "$body" --argjson labels "[$LABEL_ID]" \
      '{title: $title, body: $body, labels: $labels}')
  else
    payload=$(jq -n --arg title "$title" --arg body "$body" \
      '{title: $title, body: $body}')
  fi

  local result
  result=$(api_post "repos/${REPO}/issues" "$payload") || {
    log_error "failed to create issue"
    exit 1
  }

  local number url
  number=$(echo "$result" | jq -r '.number')
  url=$(echo "$result" | jq -r '.html_url')
  echo "Created issue #${number}: ${url}"
}

cmd_issue_close() {
  local issue_num="$1"; shift
  local comment=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --comment=*) comment="${1#--comment=}"; shift ;;
      --comment)   comment="$2"; shift 2 ;;
      *) log_error "unknown option: $1"; exit 1 ;;
    esac
  done

  # Add comment if provided
  if [[ -n "$comment" ]]; then
    local comment_payload
    comment_payload=$(jq -n --arg body "$comment" '{body: $body}')
    api_post "repos/${REPO}/issues/${issue_num}/comments" "$comment_payload" >/dev/null || {
      log_error "failed to add comment to issue #${issue_num}"
      exit 1
    }
  fi

  # Close the issue
  local close_payload='{"state": "closed"}'
  api_patch "repos/${REPO}/issues/${issue_num}" "$close_payload" >/dev/null || {
    log_error "failed to close issue #${issue_num}"
    exit 1
  }

  echo "Closed issue #${issue_num}"
}

cmd_issue_comment() {
  local issue_num="$1"; shift
  local body=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --body=*) body="${1#--body=}"; shift ;;
      --body)   body="$2"; shift 2 ;;
      *) log_error "unknown option: $1"; exit 1 ;;
    esac
  done

  if [[ -z "$body" ]]; then
    log_error "issue comment requires --body"
    exit 1
  fi

  local payload
  payload=$(jq -n --arg body "$body" '{body: $body}')
  api_post "repos/${REPO}/issues/${issue_num}/comments" "$payload" >/dev/null || {
    log_error "failed to add comment to issue #${issue_num}"
    exit 1
  }

  echo "Added comment to issue #${issue_num}"
}

# --- PR commands ---

cmd_pr_create() {
  local title="" body="" head="" base="main"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title=*) title="${1#--title=}"; shift ;;
      --title)   title="$2"; shift 2 ;;
      --body=*)  body="${1#--body=}"; shift ;;
      --body)    body="$2"; shift 2 ;;
      --head=*)  head="${1#--head=}"; shift ;;
      --head)    head="$2"; shift 2 ;;
      --base=*)  base="${1#--base=}"; shift ;;
      --base)    base="$2"; shift 2 ;;
      *) log_error "unknown option: $1"; exit 1 ;;
    esac
  done

  if [[ -z "$title" || -z "$head" ]]; then
    log_error "pr create requires --title and --head"
    exit 1
  fi

  local payload
  payload=$(jq -n --arg title "$title" --arg body "$body" --arg head "$head" --arg base "$base" \
    '{title: $title, body: $body, head: $head, base: $base}')

  local result
  result=$(api_post "repos/${REPO}/pulls" "$payload") || {
    log_error "failed to create PR"
    exit 1
  }

  local number url
  number=$(echo "$result" | jq -r '.number')
  url=$(echo "$result" | jq -r '.html_url')
  echo "Created PR #${number}: ${url}"
}

# --- Argument routing ---

if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

check_deps curl jq
if [[ -z "${FORGEJO_TOKEN:-}" ]]; then
  check_deps yq
fi
resolve_forgejo_config

RESOURCE="$1"; shift

case "$RESOURCE" in
  issue)
    if [[ $# -eq 0 ]]; then
      log_error "issue requires a subcommand (list, create, close, comment)"
      exit 1
    fi
    ACTION="$1"; shift
    case "$ACTION" in
      list)    cmd_issue_list "$@" ;;
      create)  cmd_issue_create "$@" ;;
      close)
        if [[ $# -eq 0 ]]; then
          log_error "issue close requires an issue number"
          exit 1
        fi
        cmd_issue_close "$@"
        ;;
      comment)
        if [[ $# -eq 0 ]]; then
          log_error "issue comment requires an issue number"
          exit 1
        fi
        cmd_issue_comment "$@"
        ;;
      *) log_error "unknown issue command: $ACTION"; usage; exit 1 ;;
    esac
    ;;
  pr)
    if [[ $# -eq 0 ]]; then
      log_error "pr requires a subcommand (create)"
      exit 1
    fi
    ACTION="$1"; shift
    case "$ACTION" in
      create) cmd_pr_create "$@" ;;
      *) log_error "unknown pr command: $ACTION"; usage; exit 1 ;;
    esac
    ;;
  *)
    log_error "unknown resource: $RESOURCE"
    usage
    exit 1
    ;;
esac
