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
        --preview 'bat --color=always --theme=1337 --highlight-line {2} {1}' \
        --preview-window 'right,60%,wrap'
}