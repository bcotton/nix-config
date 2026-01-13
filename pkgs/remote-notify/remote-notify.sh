#!/usr/bin/env bash
# remote-notify: Send notifications to remote Mac via SSH tunnel
# Falls back to local notify-send if tunnel is not available

set -euo pipefail

# Port where notification-receiver listens (via SSH RemoteForward)
REMOTE_NOTIFY_PORT="${REMOTE_NOTIFY_PORT:-7892}"

usage() {
    cat <<EOF
Usage: remote-notify -t TITLE -m MESSAGE [-s SUBTITLE]
       command | remote-notify -t TITLE [-s SUBTITLE]

Send a notification to the remote Mac via SSH tunnel.
Falls back to local notify-send if tunnel is not available.

Options:
  -t TITLE     Notification title (required)
  -m MESSAGE   Notification message (or read from stdin if not provided)
  -s SUBTITLE  Notification subtitle (optional)
  -h, --help   Show this help message

Environment variables:
  REMOTE_NOTIFY_PORT  Port for notification-receiver (default: 7892)

Examples:
  remote-notify -t "Build Complete" -m "All tests passed"
  remote-notify -t "CI Pipeline" -m "Deployed to prod" -s "nix-01"
  echo "Long output..." | remote-notify -t "Command Output"
EOF
}

send_notification() {
    local title="$1"
    local message="$2"
    local subtitle="${3:-}"

    # Build the payload: title\nmessage\nsubtitle
    local payload="$title"$'\n'"$message"
    if [[ -n "$subtitle" ]]; then
        payload="$payload"$'\n'"$subtitle"
    fi

    # Send to notification-receiver via the SSH tunnel using bash /dev/tcp
    # This avoids netcat compatibility issues across different distributions
    timeout 5 bash -c "echo '$payload' > /dev/tcp/127.0.0.1/$REMOTE_NOTIFY_PORT" 2>/dev/null
}

check_tunnel() {
    # Quick check if tunnel is available
    timeout 2 bash -c "echo '' > /dev/tcp/127.0.0.1/$REMOTE_NOTIFY_PORT" 2>/dev/null
}

main() {
    local title=""
    local message=""
    local subtitle=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--title)
                title="$2"
                shift 2
                ;;
            -m|--message)
                message="$2"
                shift 2
                ;;
            -s|--subtitle)
                subtitle="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
    done

    # Title is required
    if [[ -z "$title" ]]; then
        echo "Error: Title (-t) is required" >&2
        usage >&2
        exit 1
    fi

    # If no message provided, read from stdin
    if [[ -z "$message" ]]; then
        if [[ -t 0 ]]; then
            echo "Error: Message (-m) is required, or pipe message via stdin" >&2
            usage >&2
            exit 1
        fi
        message=$(cat)
    fi

    if [[ -z "$message" ]]; then
        echo "Error: No message provided" >&2
        exit 1
    fi

    # Try to send through tunnel first
    if check_tunnel && send_notification "$title" "$message" "$subtitle"; then
        exit 0
    fi

    # Fall back to local notify-send if available
    if command -v notify-send &>/dev/null; then
        echo "Note: Remote tunnel not available, using local notify-send" >&2
        if [[ -n "$subtitle" ]]; then
            notify-send "$title" "$subtitle: $message"
        else
            notify-send "$title" "$message"
        fi
        exit 0
    fi

    echo "Error: Remote tunnel not available and no local notify-send found" >&2
    exit 1
}

main "$@"
