# RGF-Search Plugin
# Provides rgf function for ripgrep + fzf + bat integration

rgf() {
  local query="$1"
  shift
  rg --color=always --line-number --no-heading --smart-case "$query" "$@" | \
    fzf --layout=reverse \
        --border \
        --ansi \
        --delimiter : \
        --preview 'line={2}; start=$((line > 10 ? line - 10 : 1)); bat --color=always --theme=1337 --highlight-line $line --line-range $start: {1}' \
        --preview-window 'right,60%'
}

alias frg=rgf