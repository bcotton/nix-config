#!/usr/bin/env bash
# notification-receiver: Listen for notifications on a TCP port and display via terminal-notifier
# Used with SSH RemoteForward to allow remote hosts to send notifications to local Mac
#
# terminal-notifier appears in System Settings > Notifications where you can
# configure it to show as "Alerts" (persistent) instead of "Banners" (auto-dismiss)

set -euo pipefail

PORT="${NOTIFICATION_RECEIVER_PORT:-7892}"
LOG_FILE="${NOTIFICATION_RECEIVER_LOG:-/tmp/notification-receiver.log}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

show_notification() {
    local title=""
    local message=""
    local subtitle=""
    local line_num=0

    # Read lines: line 1 = title, line 2 = message, line 3 = subtitle (optional)
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(echo "$line" | tr -d '\r')
        case $line_num in
            0) title="$line" ;;
            1) message="$line" ;;
            2) subtitle="$line" ;;
        esac
        line_num=$((line_num + 1))
    done

    if [[ -z "$title" ]] && [[ -z "$message" ]]; then
        log "Received empty notification, ignoring"
        return
    fi

    # Default title if empty
    [[ -z "$title" ]] && title="Notification"

    log "Showing notification: title='$title' message='$message' subtitle='$subtitle'"

    # Build terminal-notifier command
    local cmd=(terminal-notifier -title "$title" -message "$message")

    if [[ -n "$subtitle" ]]; then
        cmd+=(-subtitle "$subtitle")
    fi

    # Add sound for attention
    cmd+=(-sound default)

    if "${cmd[@]}" 2>> "$LOG_FILE"; then
        echo "OK"
    else
        log "Failed to show notification"
        echo "ERROR"
    fi
}

handle_connection() {
    show_notification
}

main() {
    log "Starting notification-receiver on port $PORT"

    # Use socat to listen for TCP connections
    # For each connection, read notification data and display
    exec socat TCP-LISTEN:"$PORT",bind=127.0.0.1,reuseaddr,fork EXEC:"$0 --handle-connection"
}

# Allow script to be called with --handle-connection for socat EXEC
if [[ "${1:-}" == "--handle-connection" ]]; then
    handle_connection
else
    main "$@"
fi
