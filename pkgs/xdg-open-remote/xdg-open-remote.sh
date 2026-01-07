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

send_url() {
    local url="$1"
    # Send URL to browser-opener via the SSH tunnel using bash /dev/tcp
    # This avoids netcat compatibility issues across different distributions
    timeout 2 bash -c "echo '$url' > /dev/tcp/127.0.0.1/$REMOTE_BROWSER_PORT" 2>/dev/null
}

main() {
    if [[ $# -lt 1 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        usage
        exit 0
    fi

    local url="$1"

    # Try to send through tunnel first
    if send_url "$url"; then
        exit 0
    fi

    # Fall back to local xdg-open if available
    if command -v xdg-open &>/dev/null; then
        echo "Note: Remote tunnel not available, using local browser" >&2
        exec xdg-open "$url"
    else
        echo "Error: Remote tunnel not available and no local xdg-open found" >&2
        exit 1
    fi
}

main "$@"
