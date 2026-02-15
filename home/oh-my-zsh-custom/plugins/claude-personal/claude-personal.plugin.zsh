claudep() {
    source ~/.config/sensitive/.claude-personal-env
    CLAUDE_CONFIG_DIR=~/.claude-personal command claude "$@" --allow-dangerously-skip-permissions
}

claude() {
    export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
    CLAUDE_CONFIG_DIR=~/.claude command claude "$@" --allow-dangerously-skip-permissions
}
