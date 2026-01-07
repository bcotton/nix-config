#!/usr/bin/env bash
# xdg-open-remote: Open URLs in remote browser via SSH tunnel
# Falls back to local xdg-open if tunnel is not available

set -euo pipefail

# Port where browser-opener listens (via SSH RemoteForward)
REMOTE_BROWSER_PORT="${REMOTE_BROWSER_PORT:-7890}"

usage() {
    cat <<EOF
Usage: xdg-open-remote <url>

Open a URL in the remote browser via SSH tunnel.
Falls back to local xdg-open if tunnel is not available.

Environment variables:
  REMOTE_BROWSER_PORT  Port for browser-opener (default: 7890)

Examples:
  xdg-open-remote https://example.com
  xdg-open-remote file:///path/to/file.html
EOF
}

check_tunnel() {
    # Check if the SSH tunnel port is listening
    # Use timeout to avoid hanging if port isn't available
    timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/$REMOTE_BROWSER_PORT" 2>/dev/null
}

send_url() {
    local url="$1"
    # Send URL to browser-opener via the SSH tunnel
    echo "$url" | timeout 2 nc 127.0.0.1 "$REMOTE_BROWSER_PORT" 2>/dev/null
}

main() {
    if [[ $# -lt 1 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        usage
        exit 0
    fi

    local url="$1"

    # Check if we have a tunnel available
    if check_tunnel; then
        if send_url "$url"; then
            exit 0
        else
            echo "Warning: Failed to send URL through tunnel, falling back to local" >&2
        fi
    fi

    # Fall back to local xdg-open if available
    if command -v xdg-open &>/dev/null; then
        exec xdg-open "$url"
    else
        echo "Error: No remote tunnel and no local xdg-open available" >&2
        exit 1
    fi
}

main "$@"
