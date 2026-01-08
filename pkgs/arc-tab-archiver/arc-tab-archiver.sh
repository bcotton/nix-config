#!/usr/bin/env bash
# arc-tab-archiver: Capture auto-archived Arc tabs to Obsidian
# Organizes tabs by Arc space into separate markdown files with tables
set -euo pipefail

# Configuration (can be overridden via environment)
ARC_DIR="${ARC_DIR:-$HOME/Library/Application Support/Arc}"
ARC_ARCHIVE="${ARC_ARCHIVE:-$ARC_DIR/StorableArchiveItems.json}"
ARC_SIDEBAR="${ARC_SIDEBAR:-$ARC_DIR/StorableSidebar.json}"
# OBSIDIAN_DIR must be set - the directory where space files will be created
# Example: OBSIDIAN_DIR="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Bob's Projects/arc-archive"
OBSIDIAN_DIR="${OBSIDIAN_DIR:?OBSIDIAN_DIR environment variable must be set}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/arc-tab-archiver}"
STATE_FILE="${STATE_DIR}/processed.txt"

# Core Foundation epoch offset (Jan 1, 2001 to Jan 1, 1970)
CF_EPOCH_OFFSET=978307200

# Build space ID to name mapping from Arc sidebar
build_space_map() {
    jq -r '
        .sidebar.containers[1].spaces as $spaces |
        [range(0; $spaces | length; 2)] |
        map("\($spaces[.])|\($spaces[. + 1].title)") |
        .[]
    ' "$ARC_SIDEBAR" 2>/dev/null
}

# Sanitize filename (remove/replace problematic characters)
sanitize_filename() {
    local name="$1"
    echo "$name" | sed 's/[\/\\:*?"<>|]/-/g' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//'
}

# Convert CF timestamp to sortable and display dates
cf_to_dates() {
    local cf_timestamp="$1"
    local unix_timestamp
    unix_timestamp=$(echo "$cf_timestamp + $CF_EPOCH_OFFSET" | bc | cut -d. -f1)
    # Output: sortable_timestamp|display_date
    echo "${unix_timestamp}|$(date -r "$unix_timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null || date -d "@$unix_timestamp" "+%Y-%m-%d %H:%M")"
}

# Generate markdown table for a space
generate_space_file() {
    local space_name="$1"
    local safe_name
    safe_name=$(sanitize_filename "$space_name")
    local output_file="$OBSIDIAN_DIR/${safe_name}.md"
    local temp_file
    temp_file=$(mktemp)

    # Write header
    cat > "$temp_file" << EOF
# Arc Archive: ${space_name}

Auto-archived tabs from Arc browser's **${space_name}** space.

| Title | Archived |
|-------|----------|
EOF

    # Get space ID for this name
    local space_id=""
    while IFS='|' read -r id name; do
        if [[ "$name" == "$space_name" ]]; then
            space_id="$id"
            break
        fi
    done < <(build_space_map)

    if [[ -z "$space_id" ]]; then
        echo "Warning: Could not find space ID for '$space_name'" >&2
        rm -f "$temp_file"
        return
    fi

    # Extract and sort tabs for this space (newest first)
    # Filter: auto-archived, from this space (not littleArc), has URL
    jq -r --arg space_id "$space_id" '
        .items[] |
        select(type == "object" and .reason == "auto") |
        select(.source.space._0 == $space_id) |
        select(.sidebarItem.data.tab.savedURL != null) |
        [
            .archivedAt,
            (.sidebarItem.data.tab.savedTitle // .sidebarItem.data.tab.savedURL),
            .sidebarItem.data.tab.savedURL
        ] |
        @tsv
    ' "$ARC_ARCHIVE" 2>/dev/null | while IFS=$'\t' read -r archived_at title url; do
        # Convert timestamp
        local dates
        dates=$(cf_to_dates "$archived_at")
        local sort_ts="${dates%%|*}"
        local display_date="${dates##*|}"

        # Escape pipe characters in title for markdown table
        local escaped_title="${title//|/\\|}"
        # Escape brackets for markdown links in title
        escaped_title="${escaped_title//\[/\\[}"
        escaped_title="${escaped_title//\]/\\]}"

        # Output with sort key prefix (will be sorted and stripped)
        echo "${sort_ts}|[${escaped_title}](${url})|${display_date}"
    done | sort -t'|' -k1 -rn | cut -d'|' -f2- | while IFS='|' read -r linked_title date; do
        echo "| ${linked_title} | ${date} |"
    done >> "$temp_file"

    # Check if we have any tabs
    local line_count
    line_count=$(wc -l < "$temp_file")
    if [[ "$line_count" -le 6 ]]; then
        # Only header, no tabs
        rm -f "$temp_file"
        return 0
    fi

    # Move to final location
    mkdir -p "$OBSIDIAN_DIR"
    mv "$temp_file" "$output_file"
    echo "  Updated: ${safe_name}.md"
}

# Main processing
main() {
    # Check required files exist
    if [[ ! -f "$ARC_ARCHIVE" ]]; then
        echo "Error: Arc archive not found at: $ARC_ARCHIVE" >&2
        exit 1
    fi
    if [[ ! -f "$ARC_SIDEBAR" ]]; then
        echo "Error: Arc sidebar not found at: $ARC_SIDEBAR" >&2
        exit 1
    fi

    mkdir -p "$STATE_DIR"
    mkdir -p "$OBSIDIAN_DIR"

    echo "Arc Tab Archiver - Generating per-space files..."
    echo "Output directory: $OBSIDIAN_DIR"
    echo ""

    # Get unique space names from sidebar
    local space_count=0
    while IFS='|' read -r space_id space_name; do
        if [[ -n "$space_name" ]]; then
            generate_space_file "$space_name"
            ((space_count++)) || true
        fi
    done < <(build_space_map)

    echo ""
    echo "Processed $space_count spaces"
}

main "$@"
