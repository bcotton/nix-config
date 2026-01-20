# RGF-Search Plugin
# Provides rgf function for ripgrep + fzf + bat integration

rgf() {
  local query="$1"
  shift
  rg --color=always --line-number --no-heading --smart-case "$query" "$@" | \
    fzf --ansi --delimiter : --preview 'bat --color=always --highlight-line {2} {1}' --preview-window 'right,60%,wrap'
}