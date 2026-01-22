#!/usr/bin/env bash
# Copy stdin to clipboard via OSC52 escape sequence
# Works through SSH and nested tmux sessions

input=$(cat)

# Also set tmux buffer for local access
if [ -n "$TMUX" ]; then
  printf '%s' "$input" | tmux load-buffer -
fi

# Send OSC52 escape sequence
# Base64 encode the input and wrap in OSC52
encoded=$(printf '%s' "$input" | base64 | tr -d '\n')
printf '\e]52;c;%s\a' "$encoded"
