# bdl - Interactive beads issue browser with fzf
# Similar to kg for kubectl, provides fuzzy finding for beads issues

# Helper to get bead info and sanitized branch name
# Sets: _bdl_title, _bdl_branch
_bdl_get_bead_info() {
    local id="$1"
    _bdl_title=$(bd show "$id" --json 2>/dev/null | jq -r '.[0].title // empty')
    if [[ -z "$_bdl_title" ]]; then
        echo "Failed to get title for $id" >&2
        return 1
    fi
    # Sanitize branch name: lowercase, spaces to hyphens, only alphanumeric and hyphens, no consecutive/leading/trailing hyphens
    _bdl_branch=$(printf '%s' "$_bdl_title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-' | sed 's/--*/-/g; s/^-//; s/-$//')
    _bdl_branch="${_bdl_branch}-${id}"
}

# Create worktree and start work on bead
_bdl_worktree() {
    local id="$1"
    _bdl_get_bead_info "$id" || return 1
    workmux add --name "$_bdl_title" -b -p "start work on bead $id" "$_bdl_branch"
}

# Create worktree and plan the bead
_bdl_worktree_plan() {
    local id="$1"
    _bdl_get_bead_info "$id" || return 1
    workmux add --name "$_bdl_title" -b -p "TODO: plan command for bead $id" "$_bdl_branch" 
}

function bdl() {
    local preview_cmd issue_id
    local -a bd_args

    # Store arguments to pass to bd list
    bd_args=("$@")

    # Build the preview command - extract issue ID from first column
    preview_cmd='bd show {1}'

    # Main fzf command with preview
    issue_id=$(bd list ${bd_args[*]} | \
        fzf --layout=reverse \
            --border \
            --prompt="Select issue > " \
            --preview-window=right:60%:wrap \
            --preview "$preview_cmd" \
            --bind 'ctrl-r:reload(bd list '"${bd_args[*]}"')' \
            --bind 'ctrl-s:execute-silent(tmux send-keys -t :.1 "please start work on bead {1}" Enter)+abort' \
            --bind 'd:execute-silent(bd delete {1})+reload(bd list '"${bd_args[*]}"')' \
            --bind 'w:execute(zsh -ic "_bdl_worktree {1}")+abort' \
            --bind 'p:execute(zsh -ic "_bdl_worktree_plan {1}")+abort' \
            --header 'ctrl-r: refresh | ctrl-s: claude | d: delete | w: work | p: plan' | \
        awk '{print $1}')

    # If an issue was selected, show it
    if [ -n "$issue_id" ]; then
        bd show "$issue_id"
    fi
}

# Completion function for bdl - reuse bd completion if available
function _bdl {
    # Try to use bd's completion for the list subcommand
    words=(bd list "${words[@]:1}")
    (( CURRENT++ ))
    _bd 2>/dev/null || _files
}

# Register the completion
compdef _bdl bdl
