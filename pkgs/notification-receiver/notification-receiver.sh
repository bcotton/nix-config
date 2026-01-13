#!/usr/bin/env bash
# notification-receiver: Listen for notifications on a TCP port and display via osascript
# Used with SSH RemoteForward to allow remote hosts to send notifications to local Mac

set -euo pipefail

PORT="${NOTIFICATION_RECEIVER_PORT:-7892}"
LOG_FILE="${NOTIFICATION_RECEIVER_LOG:-/tmp/notification-receiver.log}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Escape double quotes for AppleScript
escape_applescript() {
    local str="$1"
    # Replace double quotes with escaped version for AppleScript
    echo "${str//\"/\\\"}"
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

    # Escape strings for AppleScript
    local escaped_title
    local escaped_message
    local escaped_subtitle
    escaped_title=$(escape_applescript "$title")
    escaped_message=$(escape_applescript "$message")
    escaped_subtitle=$(escape_applescript "$subtitle")

    # Build AppleScript command using display alert for persistent notification
    # display alert stays on screen until user clicks OK
    local alert_message="${escaped_message}"
    if [[ -n "$subtitle" ]]; then
        alert_message="${escaped_subtitle}: ${escaped_message}"
    fi
    local applescript="display alert \"${escaped_title}\" message \"${alert_message}\" buttons {\"OK\"} default button 1"

    log "Showing notification: title='$title' message='$message' subtitle='$subtitle'"

    if osascript -e "$applescript" 2>> "$LOG_FILE"; then
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
