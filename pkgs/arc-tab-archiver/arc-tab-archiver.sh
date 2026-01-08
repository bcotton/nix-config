#!/usr/bin/env bash
# arc-tab-archiver: Capture auto-archived Arc tabs to Obsidian
# Uses JSONL cache for persistent history even after Arc prunes old tabs
set -euo pipefail

# Configuration (can be overridden via environment)
ARC_DIR="${ARC_DIR:-$HOME/Library/Application Support/Arc}"
ARC_ARCHIVE="${ARC_ARCHIVE:-$ARC_DIR/StorableArchiveItems.json}"
ARC_SIDEBAR="${ARC_SIDEBAR:-$ARC_DIR/StorableSidebar.json}"
# OBSIDIAN_DIR must be set - directory for .jsonl cache and .md files
OBSIDIAN_DIR="${OBSIDIAN_DIR:?OBSIDIAN_DIR environment variable must be set}"

# Core Foundation epoch offset (Jan 1, 2001 to Jan 1, 1970)
CF_EPOCH_OFFSET=978307200

# Validate Arc archive schema
validate_archive_schema() {
    if ! jq -e '
        (type == "object") and
        has("items") and has("version") and
        (.items | type == "array") and
        (.items | length > 1) and
        (.items[0] | type == "string") and
        (.items[1] | type == "object") and
        (.items[1] | has("archivedAt", "reason", "sidebarItem", "source")) and
        (.items[1].sidebarItem | has("data")) and
        (.items[1].sidebarItem.data | has("tab"))
    ' "$ARC_ARCHIVE" > /dev/null 2>&1; then
        echo "ERROR: Arc archive schema validation failed!" >&2
        echo "Expected structure in StorableArchiveItems.json:" >&2
        echo '  { "items": ["UUID", {archivedAt, reason, sidebarItem: {data: {tab: {...}}}, source}, ...], "version": N }' >&2
        echo "Arc may have changed their format. Please report this issue." >&2
        return 1
    fi
}

# Validate Arc sidebar schema
validate_sidebar_schema() {
    if ! jq -e '
        (type == "object") and
        has("sidebar") and
        (.sidebar | has("containers")) and
        (.sidebar.containers | type == "array") and
        (.sidebar.containers | length > 1) and
        (.sidebar.containers[1] | has("spaces")) and
        (.sidebar.containers[1].spaces | type == "array") and
        (.sidebar.containers[1].spaces | length > 1) and
        (.sidebar.containers[1].spaces[0] | type == "string") and
        (.sidebar.containers[1].spaces[1] | type == "object") and
        (.sidebar.containers[1].spaces[1] | has("title"))
    ' "$ARC_SIDEBAR" > /dev/null 2>&1; then
        echo "ERROR: Arc sidebar schema validation failed!" >&2
        echo "Expected structure in StorableSidebar.json:" >&2
        echo '  { "sidebar": { "containers": [{...}, { "spaces": ["UUID", {title: "...", ...}, ...] }] } }' >&2
        echo "Arc may have changed their format. Please report this issue." >&2
        return 1
    fi
}

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

# Convert CF timestamp to display date
cf_to_display_date() {
    local cf_timestamp="$1"
    local unix_timestamp
    unix_timestamp=$(echo "$cf_timestamp + $CF_EPOCH_OFFSET" | bc | cut -d. -f1)
    date -r "$unix_timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null || date -d "@$unix_timestamp" "+%Y-%m-%d %H:%M"
}

# Get IDs already in JSONL cache
get_cached_ids() {
    local jsonl_file="$1"
    if [[ -f "$jsonl_file" ]]; then
        jq -r '.id' "$jsonl_file" 2>/dev/null | sort -u
    fi
}

# Append new tabs to JSONL cache
append_to_cache() {
    local space_id="$1"
    local space_name="$2"
    local jsonl_file="$3"
    local captured_at
    captured_at=$(date -u "+%Y-%m-%dT%H:%M:%SZ")

    # Get existing IDs
    local existing_ids
    existing_ids=$(get_cached_ids "$jsonl_file")

    # Extract new tabs from Arc and append to cache
    local new_count=0
    while IFS=$'\t' read -r id url title archived_at; do
        # Skip if already in cache
        if echo "$existing_ids" | grep -qxF "$id" 2>/dev/null; then
            continue
        fi

        # Append to JSONL (escape for JSON)
        jq -n -c \
            --arg id "$id" \
            --arg url "$url" \
            --arg title "$title" \
            --argjson archivedAt "$archived_at" \
            --arg spaceName "$space_name" \
            --arg capturedAt "$captured_at" \
            '{id: $id, url: $url, title: $title, archivedAt: $archivedAt, spaceName: $spaceName, capturedAt: $capturedAt}' \
            >> "$jsonl_file"

        ((new_count++)) || true
    done < <(jq -r --arg space_id "$space_id" '
        .items[] |
        select(type == "object" and .reason == "auto") |
        select(.source.space._0 == $space_id) |
        select(.sidebarItem.data.tab.savedURL != null) |
        [
            .sidebarItem.id,
            .sidebarItem.data.tab.savedURL,
            (.sidebarItem.data.tab.savedTitle // .sidebarItem.data.tab.savedURL),
            .archivedAt
        ] |
        @tsv
    ' "$ARC_ARCHIVE" 2>/dev/null)

    echo "$new_count"
}

# Generate markdown table from JSONL cache
generate_markdown_from_cache() {
    local space_name="$1"
    local jsonl_file="$2"
    local md_file="$3"

    if [[ ! -f "$jsonl_file" ]] || [[ ! -s "$jsonl_file" ]]; then
        return 0
    fi

    local temp_file
    temp_file=$(mktemp)

    # Write header
    cat > "$temp_file" << EOF
# Arc Archive: ${space_name}

Auto-archived tabs from Arc browser's **${space_name}** space.

| Title | Archived |
|-------|----------|
EOF

    # Read from JSONL, sort by archivedAt (newest first), generate table rows
    jq -r '[.archivedAt, .title, .url] | @tsv' "$jsonl_file" 2>/dev/null | \
    sort -t$'\t' -k1 -rn | \
    while IFS=$'\t' read -r archived_at title url; do
        local display_date
        display_date=$(cf_to_display_date "$archived_at")

        # Escape for markdown table
        local escaped_title="${title//|/\\|}"
        escaped_title="${escaped_title//\[/\\[}"
        escaped_title="${escaped_title//\]/\\]}"

        echo "| [${escaped_title}](${url}) | ${display_date} |"
    done >> "$temp_file"

    # Check if we have any tabs (more than just header)
    local line_count
    line_count=$(wc -l < "$temp_file")
    if [[ "$line_count" -le 6 ]]; then
        rm -f "$temp_file"
        return 0
    fi

    mv "$temp_file" "$md_file"
}

# Process a single space
# Outputs: new_count to stdout (for arithmetic), status to stderr
process_space() {
    local space_id="$1"
    local space_name="$2"
    local safe_name
    safe_name=$(sanitize_filename "$space_name")

    local jsonl_file="$OBSIDIAN_DIR/${safe_name}.jsonl"
    local md_file="$OBSIDIAN_DIR/${safe_name}.md"

    # Append new tabs to JSONL cache
    local new_count
    new_count=$(append_to_cache "$space_id" "$space_name" "$jsonl_file")

    # Regenerate markdown from cache
    generate_markdown_from_cache "$space_name" "$jsonl_file" "$md_file"

    # Report to stderr so stdout only has the count
    local total_count=0
    if [[ -f "$jsonl_file" ]]; then
        total_count=$(wc -l < "$jsonl_file" | tr -d ' ')
    fi

    if [[ "$new_count" -gt 0 ]] || [[ "$total_count" -gt 0 ]]; then
        echo "  ${safe_name}: +${new_count} new, ${total_count} total" >&2
    fi

    # Only output the count for capture
    echo "$new_count"
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

    # Validate schemas before processing
    echo "Validating Arc data format..."
    validate_archive_schema
    validate_sidebar_schema
    echo "Schema validation passed."
    echo ""

    mkdir -p "$OBSIDIAN_DIR"

    echo "Arc Tab Archiver - Syncing to: $OBSIDIAN_DIR"
    echo ""

    # Process each space
    local total_new=0
    local space_count=0
    while IFS='|' read -r space_id space_name; do
        if [[ -n "$space_name" ]]; then
            local new_count
            new_count=$(process_space "$space_id" "$space_name")
            ((total_new += new_count)) || true
            ((space_count++)) || true
        fi
    done < <(build_space_map)

    # Also regenerate any existing JSONL files for spaces no longer in Arc
    shopt -s nullglob
    for jsonl_file in "$OBSIDIAN_DIR"/*.jsonl; do
        if [[ -f "$jsonl_file" ]]; then
            local base_name
            base_name=$(basename "$jsonl_file" .jsonl)
            local md_file="$OBSIDIAN_DIR/${base_name}.md"

            # Get space name from first entry in JSONL
            local space_name
            space_name=$(head -1 "$jsonl_file" 2>/dev/null | jq -r '.spaceName // empty' 2>/dev/null)

            if [[ -n "$space_name" ]]; then
                # Only regenerate if we haven't already processed this space
                local safe_current
                safe_current=$(sanitize_filename "$space_name")
                if [[ "$safe_current" != "$base_name" ]]; then
                    generate_markdown_from_cache "$space_name" "$jsonl_file" "$md_file"
                fi
            fi
        fi
    done

    echo ""
    echo "Done: $total_new new tabs captured across $space_count spaces"
}

main "$@"
