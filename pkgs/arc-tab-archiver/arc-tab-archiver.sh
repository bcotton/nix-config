#!/usr/bin/env bash
# arc-tab-archiver: Capture auto-archived Arc tabs to Obsidian
set -euo pipefail

# Configuration (can be overridden via environment)
ARC_ARCHIVE="${ARC_ARCHIVE:-$HOME/Library/Application Support/Arc/StorableArchiveItems.json}"
# OBSIDIAN_FILE must be set via environment variable
# Example: OBSIDIAN_FILE="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Bob's Projects/arc-archived-tabs.md"
OBSIDIAN_FILE="${OBSIDIAN_FILE:?OBSIDIAN_FILE environment variable must be set}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/arc-tab-archiver}"
STATE_FILE="${STATE_DIR}/processed.txt"

# Core Foundation epoch: January 1, 2001 00:00:00 UTC
# Unix epoch: January 1, 1970 00:00:00 UTC
# Difference: 978307200 seconds
CF_EPOCH_OFFSET=978307200

# Convert Core Foundation timestamp to ISO date
cf_to_date() {
    local cf_timestamp="$1"
    local unix_timestamp
    unix_timestamp=$(echo "$cf_timestamp + $CF_EPOCH_OFFSET" | bc | cut -d. -f1)
    date -r "$unix_timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null || date -d "@$unix_timestamp" "+%Y-%m-%d %H:%M"
}

# Initialize state directory and files
init_state() {
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
}

# Check if an ID has been processed
is_processed() {
    local id="$1"
    grep -qxF "$id" "$STATE_FILE" 2>/dev/null
}

# Mark an ID as processed
mark_processed() {
    local id="$1"
    echo "$id" >> "$STATE_FILE"
}

# Initialize Obsidian file with header if it doesn't exist
init_obsidian_file() {
    if [[ ! -f "$OBSIDIAN_FILE" ]]; then
        mkdir -p "$(dirname "$OBSIDIAN_FILE")"
        cat > "$OBSIDIAN_FILE" << 'EOF'
# Arc Archived Tabs

Auto-captured tabs from Arc browser archive.

---

EOF
    fi
}

# Main processing
main() {
    # Check if Arc archive exists
    if [[ ! -f "$ARC_ARCHIVE" ]]; then
        echo "Error: Arc archive not found at: $ARC_ARCHIVE" >&2
        exit 1
    fi

    init_state
    init_obsidian_file

    local count=0
    local new_count=0

    # Process the JSON file
    # The file structure has entries as objects in an array
    # We need to filter for reason="auto" and extract tab data
    while IFS= read -r line; do
        local id url title archived_at archived_date

        id=$(echo "$line" | jq -r '.sidebarItem.id')

        # Skip if already processed
        if is_processed "$id"; then
            ((count++)) || true
            continue
        fi

        url=$(echo "$line" | jq -r '.sidebarItem.data.tab.savedURL // empty')
        title=$(echo "$line" | jq -r '.sidebarItem.data.tab.savedTitle // empty')
        archived_at=$(echo "$line" | jq -r '.archivedAt // empty')

        # Skip entries without URL
        if [[ -z "$url" ]]; then
            continue
        fi

        # Convert timestamp
        if [[ -n "$archived_at" ]]; then
            archived_date=$(cf_to_date "$archived_at")
        else
            archived_date="Unknown"
        fi

        # Use URL as title if title is empty
        if [[ -z "$title" ]]; then
            title="$url"
        fi

        # Append to Obsidian file
        cat >> "$OBSIDIAN_FILE" << EOF

## [$title]($url)
- Archived: $archived_date

EOF

        mark_processed "$id"
        ((new_count++)) || true
        ((count++)) || true

    done < <(jq -c '.items[] | select(type == "object" and .reason == "auto")' "$ARC_ARCHIVE" 2>/dev/null)

    echo "Processed $count auto-archived tabs, $new_count new entries added"
}

main "$@"
