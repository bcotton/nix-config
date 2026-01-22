# Arc Tab Archiver

Captures auto-archived tabs from Arc browser and saves them to an Obsidian vault as markdown tables, organized by Arc space.

## Features

- **JSONL cache** for persistent history (survives Arc's pruning of old tabs)
- **Schema validation** to detect if Arc changes their data format
- Creates one markdown file per Arc space (e.g., `Grafana.md`, `Home Lab.md`)
- Outputs markdown tables with Title (as link) and Archived Date columns
- Sorts by archive date, newest first
- Caches space names (tabs keep original space name even if renamed in Arc)

## Output Format

Each space gets paired files:

```
arc-archive/
├── Grafana.jsonl       # Persistent cache (append-only)
├── Grafana.md          # Generated table (regenerated each run)
├── Home Lab.jsonl
├── Home Lab.md
└── ...
```

### JSONL Cache Format

```jsonl
{"id":"UUID","url":"https://...","title":"Page Title","archivedAt":784380925.78,"spaceName":"Grafana","capturedAt":"2026-01-08T12:00:00Z"}
```

### Markdown Table Format

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

- `OBSIDIAN_DIR` - Directory for output files (`.jsonl` and `.md` files)

### Optional Environment Variables

- `ARC_DIR` - Path to Arc's data directory
  - Default: `~/Library/Application Support/Arc`
- `STATE_DIR` - Directory for state file (legacy, may be removed)
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

1. **Validates Arc schema** - Ensures Arc hasn't changed their data format
2. **Reads space names/IDs** from `StorableSidebar.json`
3. **For each space:**
   - Loads existing `.jsonl` cache (if any)
   - Queries Arc for auto-archived tabs
   - Appends new tabs to `.jsonl` (with cached space name)
   - Regenerates `.md` table from cache (sorted, newest first)
4. **Reports** new tabs captured per space

## Why JSONL Cache?

Arc browser prunes `StorableArchiveItems.json` after some time, deleting old archived tabs. The JSONL cache:

- Preserves all tabs ever captured
- Survives Arc's pruning
- Is append-only (safe for iCloud sync)
- Can be version-controlled
- Allows regenerating sorted tables

## Notes

- **littleArc tabs excluded**: Tabs from Arc's mini-browser are not captured
- **Files regenerated each run**: Markdown always reflects current cache
- **Space names cached**: Tabs keep their original space name
- **Schema validation**: Script exits if Arc's format changes unexpectedly

## Troubleshooting

### "Schema validation failed"

Arc may have changed their data format. Check the error message and report an issue with:
- Arc version
- Sample of the new structure (redact personal URLs if needed)

### Tabs missing from archive

Run the script more frequently (e.g., every 30 minutes) to capture tabs before Arc prunes them.

### Duplicate tabs

Delete the `.jsonl` file for the affected space and re-run. Tabs will be re-imported from Arc (if still present).

## Obsidian Integration

The output is plain markdown tables - no plugins required. If you want to query across files, consider:
- **Obsidian Bases** (built-in): Enable in Settings -> Core plugins -> Bases
- **Dataview/Datacore**: Community plugins for more complex queries
