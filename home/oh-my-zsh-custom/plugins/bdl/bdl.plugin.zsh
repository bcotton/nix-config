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
    local preview_cmd issue_id preview_pos
    local -a bd_args

    # Store arguments to pass to bd list
    bd_args=("$@")

    # Use top/bottom layout if terminal is taller than wide
    preview_pos='right:60%:wrap'
    [[ $(tput lines) -gt $(tput cols) ]] && preview_pos='up:50%:wrap'

    # Build the preview command - ID is prepended as first field
    # Use expect for color output in preview pane
    preview_cmd="expect -c 'spawn -noecho bd show {1}; expect eof' 2>&1 | sed 's/\r\$//'"

    # Preprocessing: prepend ID to each line for consistent {1} access
    # awk extracts ID (matches namespace-shortcode pattern) and prepends it
    # Only output lines that have a valid ID (filters out summary/legend lines)
    local preprocess='awk '\''{for(i=1;i<=NF;i++) if($i ~ /^[a-z]+-[a-z0-9.]+$/) {print $i, $0; next}}'\'''

    # Use expect to force TTY for color output, strip carriage returns
    local list_cmd="expect -c 'spawn -noecho bd list --pretty ${bd_args[*]}; expect eof' 2>&1 | sed 's/\r\$//'"
    local reload_cmd="$list_cmd | $preprocess"

    # Main fzf command with preview
    # --ansi: render ANSI color codes
    # --with-nth=2.. hides the prepended ID from display but {1} still accesses it
    issue_id=$(eval "$list_cmd" | eval "$preprocess" | \
        fzf --ansi \
            --layout=reverse \
            --border \
            --with-nth=2.. \
            --prompt="Select issue > " \
            --preview-window="$preview_pos" \
            --preview "$preview_cmd" \
            --bind "ctrl-r:reload($reload_cmd)" \
            --bind 'ctrl-s:execute-silent(tmux send-keys -t :.1 "please start work on bead {1}" Enter)+abort' \
            --bind 'ctrl-d:execute-silent(bd delete {1})+reload('"$reload_cmd"')' \
            --bind 'ctrl-w:execute(zsh -ic "_bdl_worktree {1}")+abort' \
            --bind 'ctrl-p:execute(zsh -ic "_bdl_worktree_plan {1}")+abort' \
            --bind 'ctrl-e:execute(bd edit {1})+reload('"$reload_cmd"')' \
            --bind 'ctrl-y:execute-silent(echo -n {1} | pbcopy)' \
            --header 'ctrl-r: refresh | ctrl-s: claude | ctrl-d: delete | ctrl-w: work | ctrl-p: plan | ctrl-e: edit | ctrl-y: copy' | \
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
