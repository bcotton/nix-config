# Arc Tab Archiver

Captures auto-archived tabs from Arc browser and saves them to an Obsidian vault as markdown.

## Features

- Reads Arc's `StorableArchiveItems.json` to find auto-archived tabs
- Filters for only auto-archived tabs (not manually archived)
- Converts Arc's Core Foundation timestamps to human-readable dates
- Tracks processed tabs to prevent duplicates
- Outputs markdown formatted for Obsidian

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

- `OBSIDIAN_FILE` - Path to the Obsidian markdown file for output

### Optional Environment Variables

- `ARC_ARCHIVE` - Path to Arc's StorableArchiveItems.json
  - Default: `~/Library/Application Support/Arc/StorableArchiveItems.json`
- `STATE_DIR` - Directory for state file tracking processed tabs
  - Default: `~/.local/state/arc-tab-archiver`

### Manual Run

```bash
OBSIDIAN_FILE="$HOME/path/to/your/vault/arc-archived-tabs.md" arc-tab-archiver
```

### Automatic Scheduling with launchd

1. Copy the plist template:
   ```bash
   cp com.bcotton.arc-tab-archiver.plist ~/Library/LaunchAgents/
   ```

2. Edit the plist to update paths:
   - Update `ProgramArguments` to point to your installed binary
   - Update `OBSIDIAN_FILE` environment variable to your vault path

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

## Output Format

Each archived tab is saved as:

```markdown
## [Tab Title](https://url.example.com)
- Archived: YYYY-MM-DD HH:MM
```

## State File

Processed tab IDs are stored in `~/.local/state/arc-tab-archiver/processed.txt` (or `$STATE_DIR/processed.txt`). Delete this file to reprocess all tabs.
