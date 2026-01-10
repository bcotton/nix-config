#!/usr/bin/env bash
# clipboard-receiver: Listen for text on a TCP port and copy to clipboard via pbcopy
# Used with SSH RemoteForward to allow remote hosts to copy to local Mac clipboard

set -euo pipefail

PORT="${CLIPBOARD_RECEIVER_PORT:-7891}"
LOG_FILE="${CLIPBOARD_RECEIVER_LOG:-/tmp/clipboard-receiver.log}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

copy_to_clipboard() {
    local text
    text=$(cat)

    if [[ -z "$text" ]]; then
        log "Received empty text, ignoring"
        return
    fi

    # Copy to clipboard
    if echo -n "$text" | pbcopy; then
        log "Copied ${#text} chars to clipboard"
        echo "OK"
    else
        log "Failed to copy to clipboard"
        echo "ERROR"
    fi
}

handle_connection() {
    copy_to_clipboard
}

main() {
    log "Starting clipboard-receiver on port $PORT"

    # Use socat to listen for TCP connections
    # For each connection, read text and copy to clipboard
    exec socat TCP-LISTEN:"$PORT",bind=127.0.0.1,reuseaddr,fork EXEC:"$0 --handle-connection"
}

# Allow script to be called with --handle-connection for socat EXEC
if [[ "${1:-}" == "--handle-connection" ]]; then
    handle_connection
else
    main "$@"
fi
