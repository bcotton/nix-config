# bd-completion.plugin.zsh
# Custom completion for bd (beads) issue tracker with issue ID completion
#
# This plugin adds issue ID completion for bd commands that accept issue IDs.
# It caches the issue list for performance and provides issue titles as descriptions.
#
# Usage: Call _bd_setup_completion after bd's built-in completion is loaded
#        (typically via zsh-defer after the main bd completion)

# Cache settings
typeset -g _BD_COMPLETION_CACHE_FILE="/tmp/bd-completion-cache-${UID}"
typeset -g _BD_COMPLETION_CACHE_TTL=30  # seconds

# Commands that accept issue IDs as arguments
typeset -ga _BD_ISSUE_ID_COMMANDS=(
  show
  update
  close
  delete
  edit
  reopen
  comments
  dep
  duplicate
  defer
  undefer
  supersede
  label
)

# Function to get issue completions with caching
_bd_get_issues() {
  local cache_file="$_BD_COMPLETION_CACHE_FILE"
  local now=$(date +%s)
  local cache_valid=0

  # Check if cache exists and is fresh
  if [[ -f "$cache_file" ]]; then
    local cache_time
    if [[ "$OSTYPE" == darwin* ]]; then
      cache_time=$(stat -f %m "$cache_file" 2>/dev/null)
    else
      cache_time=$(stat -c %Y "$cache_file" 2>/dev/null)
    fi
    # Only compare if we got a valid cache_time
    if [[ -n "$cache_time" ]] && (( now - cache_time < _BD_COMPLETION_CACHE_TTL )); then
      cache_valid=1
    fi
  fi

  if (( ! cache_valid )); then
    # Refresh cache - get open issues (most useful for completion)
    {
      $HOME/.local/bin/bd list --json --status open 2>/dev/null | \
        jq -r '.[] | "\(.id)\t\(.title | gsub("\n"; " ") | .[0:50])"' 2>/dev/null
    } > "$cache_file.tmp" && mv "$cache_file.tmp" "$cache_file"
  fi

  cat "$cache_file" 2>/dev/null
}

# Custom completion function for bd issue IDs
_bd_complete_issue_id() {
  local -a issues
  local id title

  while IFS=$'\t' read -r id title; do
    [[ -n "$id" ]] && issues+=("${id}:${title}")
  done < <(_bd_get_issues)

  _describe -t issues 'issue' issues
}

# Force refresh of issue cache
bd-refresh-completions() {
  rm -f "$_BD_COMPLETION_CACHE_FILE"
  _bd_get_issues > /dev/null
  echo "bd completion cache refreshed"
}

# Setup function to be called after bd completion is loaded
_bd_setup_completion() {
  # Check if _bd exists (from bd completion zsh)
  if (( ${+functions[_bd]} )); then
    # Save original completion function if not already saved
    if (( ! ${+functions[_bd_original]} )); then
      functions[_bd_original]="${functions[_bd]}"
    fi
    # Replace _bd with our enhanced version that adds issue ID completion
    _bd() {
      local cmd=${words[2]}
      # Check if we're completing an issue ID command
      if (( ${_BD_ISSUE_ID_COMMANDS[(Ie)$cmd]} )); then
        # If we're past the command name, complete issue IDs
        if (( CURRENT > 2 )); then
          _bd_complete_issue_id
          return
        fi
      fi
      # Fall back to original bd completion
      _bd_original "$@"
    }

    # Pre-warm the cache in background
    ( _bd_get_issues > /dev/null 2>&1 & )
  fi
}

# Cleanup cache on shell exit
trap 'rm -f "$_BD_COMPLETION_CACHE_FILE" "$_BD_COMPLETION_CACHE_FILE.tmp"' EXIT
