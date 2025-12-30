claudep() {
    source ~/.config/sensitive/.claude-personal-env
    CLAUDE_CONFIG_DIR=~/.claude-personal claude "$@"
}