claudep() {
    source ~/.config/sensitive/.claude-personal-env
    CLAUDE_CONFIG_DIR=~/.claude-personal command claude "$@" --allow-dangerously-skip-permissions
}

claude() {
    CLAUDE_CONFIG_DIR=~/.claude command claude "$@" --allow-dangerously-skip-permissions
}