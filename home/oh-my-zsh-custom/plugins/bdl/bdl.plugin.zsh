# bdl - Interactive beads issue browser with fzf
# Similar to kg for kubectl, provides fuzzy finding for beads issues

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
            --header 'ctrl-r: refresh' | \
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
