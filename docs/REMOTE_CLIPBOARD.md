# Remote Clipboard Sync

Copy text from remote Linux hosts to your local Mac clipboard via SSH reverse port forwarding.

## Overview

When working on remote Linux hosts via SSH, you often want to copy text (command output, file contents, etc.) to your local Mac's clipboard. This feature tunnels those copy operations back to your Mac.

Two methods are available:
1. **OSC52** - Terminal escape sequences (automatic, works in tmux)
2. **Daemon** - TCP listener for CLI tools (explicit, works anywhere)

## Architecture

```
┌─────────────────┐         SSH Tunnel          ┌─────────────────┐
│   Linux Host    │    RemoteForward 7891       │      Mac        │
│                 │ ◄──────────────────────────►│                 │
│   remote-copy   │         localhost:7891      │clipboard-receiver│
│    (client)     │                             │   (listener)    │
└─────────────────┘                             └─────────────────┘
        │                                               │
        │ sends text                                    │ copies
        ▼                                               ▼
   echo "text" | remote-copy                       pbcopy
```

1. **Mac**: `clipboard-receiver` daemon listens on `localhost:7891`
2. **SSH**: `RemoteForward 7891 localhost:7891` tunnels the port to remote hosts
3. **Linux**: `remote-copy` sends text through the tunnel
4. **Mac**: Text is copied to clipboard via `pbcopy`

## Components

### clipboard-receiver (macOS)

A launchd service that:
- Listens on TCP port 7891 using socat
- Receives text from connections
- Copies to clipboard using `pbcopy`
- Logs to `/tmp/clipboard-receiver.log`

**Package**: `pkgs/clipboard-receiver/`
**Module**: `home/modules/clipboard-receiver.nix`
**Service**: Defined in `hosts/common/darwin-common.nix`

### remote-copy (Linux)

A shell script that:
- Reads text from stdin or file
- Checks if SSH tunnel is available
- Sends text through tunnel if available
- Falls back to tmux buffer if tunnel unavailable

**Package**: `pkgs/remote-copy/`
**Module**: `home/modules/remote-copy.nix`

### OSC52 Support

Terminal-native clipboard via escape sequences:
- Configured in `home/modules/tmux-plugins.nix`
- `set -g set-clipboard on` - enables clipboard integration
- `set -g allow-passthrough all` - works through nested tmux/SSH (all panes, not just active)

### tmux-fingers Integration

tmux-fingers uses `tmux load-buffer -w` for OSC52 clipboard support. A patched version is used via overlay (`overlays/tmux-fingers.nix`) that fixes stdin handling for proper OSC52 passthrough in nested tmux sessions.

## Configuration

### Enabling (already done in bcotton.nix)

```nix
# Automatically enabled based on platform
programs.clipboard-receiver.enable = pkgs.stdenv.isDarwin;
programs.remote-copy.enable = pkgs.stdenv.isLinux;
```

### SSH RemoteForward

Configured in `home/bcotton.nix`:

```nix
programs.ssh = {
  extraConfig = ''
    Host admin condo-01 natalya-01 nas-01 nix-01 nix-02 nix-03 nix-04 imac-01 imac-02 dns-01 octoprint frigate-host
      RemoteForward 7891 localhost:7891
  '';
};
```

### Environment Variables

| Variable | Set On | Purpose |
|----------|--------|---------|
| `REMOTE_CLIPBOARD_PORT` | Linux | Port for tunnel (default: 7891) |

### Shell Aliases

On Linux, `pbcopy` is aliased to `remote-copy` when enabled. This is a shell alias (unlike the `xdg-open` wrapper) because `pbcopy` is typically only used interactively from the shell.

## Usage

### Basic Usage

```bash
# On any Linux host (after SSH with RemoteForward)
echo "hello world" | remote-copy

# Copy file contents
remote-copy myfile.txt

# Pipe command output
cat /etc/hosts | remote-copy

# Using the pbcopy alias (like macOS)
echo "hello" | pbcopy
```

### OSC52 (Terminal Native)

OSC52 works automatically in terminals that support it:
- Standard tmux yank operations copy to Mac clipboard
- Works in vim/neovim with clipboard configured
- No explicit commands needed

```bash
# In tmux, select text and press 'y' - copies to Mac clipboard automatically
```

### Tmux Sessions

The feature works with tmux reconnection:
- `REMOTE_CLIPBOARD_PORT` is exported in shell environment
- OSC52 works through nested tmux via `allow-passthrough`

### Verifying the Setup

**On Mac:**
```bash
# Check if service is running
launchctl list | grep clipboard-receiver

# Check if port is listening
lsof -i :7891

# Test manually
echo "test" | nc localhost 7891
pbpaste  # should show "test"
```

**On Linux (via SSH):**
```bash
# Check if tunnel is active
ss -tln | grep 7891

# Test the remote copy
echo "hello from remote" | remote-copy

# Check environment
echo $REMOTE_CLIPBOARD_PORT
```

## Troubleshooting

### Clipboard not syncing on Mac

1. Check if service is running:
   ```bash
   launchctl list | grep clipboard-receiver
   ```

2. Check logs:
   ```bash
   tail -f /tmp/clipboard-receiver.log
   tail -f /tmp/clipboard-receiver.error.log
   ```

3. Restart the service:
   ```bash
   launchctl unload ~/Library/LaunchAgents/org.nixos.clipboard-receiver.plist
   launchctl load ~/Library/LaunchAgents/org.nixos.clipboard-receiver.plist
   ```

### Tunnel not working

1. Verify SSH was started with RemoteForward:
   ```bash
   # On Linux host
   ss -tln | grep 7891
   ```

2. Check if another SSH session is using the port (first connection wins)

3. Manually test the tunnel:
   ```bash
   # On Linux
   echo "test" | timeout 5 bash -c 'cat > /dev/tcp/127.0.0.1/7891'
   ```

### remote-copy falls back to tmux buffer

This is expected behavior when the tunnel is not available. Check:
- SSH session includes the RemoteForward
- No other process is using port 7891

### OSC52 not working

1. Check terminal support:
   - iTerm2: Settings > General > Selection > "Applications in terminal may access clipboard"
   - Alacritty: Works by default
   - kitty: Works by default
   - Terminal.app: Limited support

2. Verify tmux config:
   ```bash
   tmux show-options -g | grep clipboard
   tmux show-options -g | grep passthrough
   ```

### Multiple SSH sessions

Only the first SSH connection's RemoteForward will succeed. Subsequent connections to the same host won't be able to bind port 7891. This is a limitation of the approach.

**Workaround**: Use a single SSH session with tmux for persistent work.

## Files

| File | Purpose |
|------|---------|
| `pkgs/clipboard-receiver/default.nix` | Mac listener package |
| `pkgs/clipboard-receiver/clipboard-receiver.sh` | Listener script |
| `pkgs/remote-copy/default.nix` | Linux client package |
| `pkgs/remote-copy/remote-copy.sh` | Client script |
| `home/modules/clipboard-receiver.nix` | Mac Home Manager module |
| `home/modules/remote-copy.nix` | Linux Home Manager module |
| `home/modules/tmux-plugins.nix` | tmux OSC52 configuration |
| `hosts/common/darwin-common.nix` | Launchd service definition |
| `overlays/tmux-fingers.nix` | tmux-fingers stdin fix overlay |

## Security Considerations

- The listener only binds to `127.0.0.1` (localhost)
- SSH tunnel is encrypted
- Text-only (no code execution)
- No authentication on the local socket (relies on localhost binding)
- Size limits handled by TCP buffer/timeout

## Related

- [REMOTE_BROWSER.md](REMOTE_BROWSER.md) - Similar system for opening URLs
