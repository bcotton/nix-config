# Arc Tab Archiver

Captures auto-archived tabs from Arc browser and saves them to an Obsidian vault as markdown tables, organized by Arc space.

## Features

- Reads Arc's `StorableArchiveItems.json` and `StorableSidebar.json`
- Filters for only auto-archived tabs (excludes manual archives and littleArc)
- Creates one markdown file per Arc space (e.g., `Grafana.md`, `Home Lab.md`)
- Outputs markdown tables with Title (as link) and Archived Date columns
- Sorts by archive date, newest first
- Regenerates files on each run (always up-to-date with Arc)

## Output Format

Each space gets its own file with a table:

```markdown
# Arc Archive: Grafana

Auto-archived tabs from Arc browser's **Grafana** space.

| Title | Archived |
|-------|----------|
| [OpenTelemetry Docs](https://opentelemetry.io/docs/) | 2026-01-07 11:20 |
| [Prometheus PR #17223](https://github.com/prometheus/...) | 2026-01-07 11:05 |
```

## Installation

### Build from flake

```bash
nix build '.#arc-tab-archiver'
```

### Install to profile

```bash
nix profile install '.#arc-tab-archiver'
```

## Usage

### Required Environment Variable

- `OBSIDIAN_DIR` - Directory for output files (will create one `.md` file per space)

### Optional Environment Variables

- `ARC_DIR` - Path to Arc's data directory
  - Default: `~/Library/Application Support/Arc`
- `STATE_DIR` - Directory for state file
  - Default: `~/.local/state/arc-tab-archiver`

### Manual Run

```bash
OBSIDIAN_DIR="$HOME/path/to/vault/arc-archive" arc-tab-archiver
```

### Automatic Scheduling with launchd

1. Copy the plist template:
   ```bash
   cp com.bcotton.arc-tab-archiver.plist ~/Library/LaunchAgents/
   ```

2. Edit the plist to update paths:
   - Update `ProgramArguments` to point to your installed binary
   - Update `OBSIDIAN_DIR` to your vault subdirectory

3. Load the agent:
   ```bash
   launchctl load ~/Library/LaunchAgents/com.bcotton.arc-tab-archiver.plist
   ```

4. Verify it's running:
   ```bash
   launchctl list | grep arc-tab-archiver
   ```

5. Check logs:
   ```bash
   tail -f ~/Library/Logs/arc-tab-archiver.log
   ```

### Unload the agent

```bash
launchctl unload ~/Library/LaunchAgents/com.bcotton.arc-tab-archiver.plist
```

## How It Works

1. Reads space names and IDs from `StorableSidebar.json`
2. For each space, queries `StorableArchiveItems.json` for auto-archived tabs
3. Converts Core Foundation timestamps to human-readable dates
4. Generates a markdown table sorted by date (newest first)
5. Writes to `OBSIDIAN_DIR/{SpaceName}.md`

## Notes

- **littleArc tabs excluded**: Tabs from Arc's mini-browser are not captured
- **Files regenerated each run**: Unlike append-mode, this always rebuilds the full table
- **Space names sanitized**: Characters like `/\:*?"<>|` are replaced with `-`

## Obsidian Integration

The output is plain markdown tables - no plugins required. If you want to query across files, consider:
- **Obsidian Bases** (built-in): Enable in Settings → Core plugins → Bases
- **Dataview/Datacore**: Community plugins for more complex queries

Sources:
- [Dataview vs Datacore vs Obsidian Bases](https://obsidian.rocks/dataview-vs-datacore-vs-obsidian-bases/)
- [How to Migrate to Obsidian Bases from Dataview](https://practicalpkm.com/moving-to-obsidian-bases-from-dataview/)
