# Create aliases and ensure they override any existing ones
autoload -U add-zsh-hook

add-zsh-hook precmd _override_grf_aliases

function _override_grf_aliases() {
    # Only need to run this once after plugins are loaded
    add-zsh-hook -d precmd _override_grf_aliases
    
    # Unalias if they exist, then set our aliases
    unalias grf 2>/dev/null
    unalias grfl 2>/dev/null
    
    # Define our function as a named function rather than an alias
    # This ensures it takes precedence over aliases from other plugins
    function grf() {
        git reflog | fzf --layout=reverse \
            --border \
            --preview 'git show --color=always {1}' \
            --preview-window=right:60%:wrap
    }
    
    # Set our grfl alias to point to our grf function
    alias grfl='grf'
}

compdef grf=git
compdef grfl=git

# Add help text for the function
function _grf_help() {
    echo "Usage: grf"
    echo "Interactive git reflog viewer with fzf preview"
}

# Register the help text
[[ -n "${_comps[grf]}" ]] && compdef _grf_help grf
