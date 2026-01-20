_fzf_cd() {
    local selected_dir
    selected_dir=$(fd -t d . "$1" | fzf +m --height 50% --preview 'exa -T --color=always {}')
    if [[ -n "$selected_dir" ]]; then
        # Change to the selected directory
        cd "$selected_dir" || return 1
    fi
}

_custom_cd() {
    # If there's a partial word, use normal completion
    if [[ -n ${words[2]} && ${words[2]} != */ ]]; then
        z
    else
        # If empty or ends with /, use fzf
        _fzf_cd "${words[2]}"
        return 0
    fi
}

# Remove existing cd completion
compdef -d cd

# Add your custom completion
compdef _custom_cd cd