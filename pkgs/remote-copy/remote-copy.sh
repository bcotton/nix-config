#!/usr/bin/env bash
# remote-copy: Copy text to remote clipboard via SSH tunnel
# Falls back to tmux buffer if tunnel is not available

set -euo pipefail

# Port where clipboard-receiver listens (via SSH RemoteForward)
REMOTE_CLIPBOARD_PORT="${REMOTE_CLIPBOARD_PORT:-7891}"

usage() {
    cat <<EOF
Usage: remote-copy [file]
       command | remote-copy

Copy text to the remote clipboard via SSH tunnel.
Falls back to tmux buffer if tunnel is not available.

Arguments:
  file    Optional file to read from (reads from stdin if not provided)

Environment variables:
  REMOTE_CLIPBOARD_PORT  Port for clipboard-receiver (default: 7891)

Examples:
  echo "hello" | remote-copy
  remote-copy myfile.txt
  cat /etc/hosts | remote-copy
EOF
}

send_to_clipboard() {
    local text="$1"
    # Send text to clipboard-receiver via the SSH tunnel using bash /dev/tcp
    # This avoids netcat compatibility issues across different distributions
    timeout 5 bash -c "echo -n '$text' > /dev/tcp/127.0.0.1/$REMOTE_CLIPBOARD_PORT" 2>/dev/null
}

check_tunnel() {
    # Quick check if tunnel is available
    timeout 2 bash -c "echo '' > /dev/tcp/127.0.0.1/$REMOTE_CLIPBOARD_PORT" 2>/dev/null
}

main() {
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi

    local text

    # Read from file if provided, otherwise from stdin
    if [[ -n "${1:-}" ]] && [[ -f "$1" ]]; then
        text=$(cat "$1")
    else
        text=$(cat)
    fi

    if [[ -z "$text" ]]; then
        echo "Error: No text to copy" >&2
        exit 1
    fi

    # Try to send through tunnel first
    if check_tunnel && send_to_clipboard "$text"; then
        exit 0
    fi

    # Fall back to tmux buffer if available
    if [[ -n "${TMUX:-}" ]] && command -v tmux &>/dev/null; then
        echo -n "$text" | tmux load-buffer -
        echo "Note: Remote tunnel not available, stored in tmux buffer" >&2
        exit 0
    fi

    echo "Error: Remote tunnel not available and not in tmux session" >&2
    exit 1
}

main "$@"
