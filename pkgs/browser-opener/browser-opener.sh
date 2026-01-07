#!/usr/bin/env bash
# browser-opener: Listen for URLs on a TCP port and open them in the default browser
# Used with SSH RemoteForward to allow remote hosts to open URLs on local Mac

set -euo pipefail

PORT="${BROWSER_OPENER_PORT:-7890}"
LOG_FILE="${BROWSER_OPENER_LOG:-/tmp/browser-opener.log}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

open_url() {
    local url="$1"
    # Trim whitespace and validate URL
    url=$(echo "$url" | tr -d '\r\n' | xargs)

    if [[ -z "$url" ]]; then
        log "Received empty URL, ignoring"
        return
    fi

    # Basic URL validation - must start with http://, https://, or file://
    if [[ ! "$url" =~ ^(https?|file):// ]]; then
        log "Invalid URL format: $url"
        return
    fi

    log "Opening URL: $url"
    open "$url" 2>> "$LOG_FILE" || log "Failed to open URL: $url"
}

handle_connection() {
    while IFS= read -r line; do
        open_url "$line"
    done
}

main() {
    log "Starting browser-opener on port $PORT"

    # Use socat to listen for TCP connections
    # For each connection, read lines and open URLs
    exec socat TCP-LISTEN:"$PORT",bind=127.0.0.1,reuseaddr,fork EXEC:"$0 --handle-connection"
}

# Allow script to be called with --handle-connection for socat EXEC
if [[ "${1:-}" == "--handle-connection" ]]; then
    handle_connection
else
    main "$@"
fi
