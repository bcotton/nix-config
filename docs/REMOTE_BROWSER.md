# Remote Browser Opening

Open URLs from remote Linux hosts in your local Mac browser via SSH reverse port forwarding.

## Overview

When working on remote Linux hosts via SSH, CLI tools like `gh`, `glab`, or custom scripts often want to open URLs in a browser. This feature tunnels those requests back to your Mac to open in your default browser.

## Architecture

```
┌─────────────────┐         SSH Tunnel          ┌─────────────────┐
│   Linux Host    │    RemoteForward 7890       │      Mac        │
│                 │ ◄──────────────────────────►│                 │
│  xdg-open-remote│         localhost:7890      │  browser-opener │
│    (client)     │                             │    (listener)   │
└─────────────────┘                             └─────────────────┘
        │                                               │
        │ sends URL                                     │ opens URL
        ▼                                               ▼
   nc localhost:7890                              open <url>
```

1. **Mac**: `browser-opener` daemon listens on `localhost:7890`
2. **SSH**: `RemoteForward 7890 localhost:7890` tunnels the port to remote hosts
3. **Linux**: `xdg-open-remote` sends URLs through the tunnel
4. **Mac**: Browser opens with the requested URL

## Components

### browser-opener (macOS)

A launchd service that:
- Listens on TCP port 7890 using socat
- Receives URLs (one per line)
- Opens each URL using macOS `open` command
- Logs to `/tmp/browser-opener.log`

**Package**: `pkgs/browser-opener/`
**Module**: `home/modules/browser-opener.nix`
**Service**: Defined in `hosts/common/darwin-common.nix`

### xdg-open-remote (Linux)

A shell script that:
- Checks if SSH tunnel is available
- Sends URL through tunnel if available
- Falls back to local `xdg-open` if tunnel unavailable

**Package**: `pkgs/xdg-open-remote/`
**Module**: `home/modules/xdg-open-remote.nix`

## Configuration

### Enabling (already done in bcotton.nix)

```nix
# Automatically enabled based on platform
programs.browser-opener.enable = pkgs.stdenv.isDarwin;
programs.xdg-open-remote.enable = pkgs.stdenv.isLinux;
```

### SSH RemoteForward

Configured in `home/bcotton.nix`:

```nix
programs.ssh = {
  extraConfig = ''
    Host admin condo-01 natalya-01 nas-01 nix-01 nix-02 nix-03 nix-04 imac-01 imac-02 dns-01 octoprint frigate-host
      RemoteForward 7890 localhost:7890
  '';
};
```

### Environment Variables

| Variable | Set On | Purpose |
|----------|--------|---------|
| `REMOTE_BROWSER_PORT` | Linux | Port for tunnel (default: 7890) |
| `BROWSER` | Linux | Set to xdg-open-remote path for CLI tools |

### xdg-open Wrapper

On Linux, an `xdg-open` wrapper script is installed that calls `xdg-open-remote`. This ensures programs that search PATH for `xdg-open` (like tmux-fingers) can find it, unlike shell aliases which only work in interactive shells.

## Usage

### Basic Usage

```bash
# On any Linux host (after SSH with RemoteForward)
xdg-open-remote https://example.com

# Or using the alias
xdg-open https://github.com

# CLI tools that respect $BROWSER work automatically
gh repo view --web
gh pr view 123 --web
```

### Tmux Sessions

The feature works with tmux reconnection:
- `REMOTE_BROWSER_PORT` is in tmux's `update-environment`
- The `refresh` function exports it on reconnect
- URL opening works after detach/reattach

### Verifying the Setup

**On Mac:**
```bash
# Check if service is running
launchctl list | grep browser-opener

# Check if port is listening
lsof -i :7890

# Test manually
echo "https://example.com" | nc localhost 7890
```

**On Linux (via SSH):**
```bash
# Check if tunnel is active
ss -tln | grep 7890

# Test the remote opener
xdg-open-remote https://example.com

# Check environment
echo $BROWSER
echo $REMOTE_BROWSER_PORT
```

## Troubleshooting

### Browser not opening on Mac

1. Check if service is running:
   ```bash
   launchctl list | grep browser-opener
   ```

2. Check logs:
   ```bash
   tail -f /tmp/browser-opener.log
   tail -f /tmp/browser-opener.error.log
   ```

3. Restart the service:
   ```bash
   launchctl unload ~/Library/LaunchAgents/org.nixos.browser-opener.plist
   launchctl load ~/Library/LaunchAgents/org.nixos.browser-opener.plist
   ```

### Tunnel not working

1. Verify SSH was started with RemoteForward:
   ```bash
   # On Linux host
   ss -tln | grep 7890
   ```

2. Check if another SSH session is using the port (first connection wins)

3. Manually test the tunnel:
   ```bash
   # On Linux
   echo "https://example.com" | nc localhost 7890
   ```

### xdg-open-remote falls back to local browser

This is expected behavior when the tunnel is not available. Check:
- SSH session includes the RemoteForward
- No other process is using port 7890

### Multiple SSH sessions

Only the first SSH connection's RemoteForward will succeed. Subsequent connections to the same host won't be able to bind port 7890. This is a limitation of the approach.

**Workaround**: Use a single SSH session with tmux for persistent work.

## Files

| File | Purpose |
|------|---------|
| `pkgs/browser-opener/default.nix` | Mac listener package |
| `pkgs/browser-opener/browser-opener.sh` | Listener script |
| `pkgs/xdg-open-remote/default.nix` | Linux client package |
| `pkgs/xdg-open-remote/xdg-open-remote.sh` | Client script |
| `home/modules/browser-opener.nix` | Mac Home Manager module |
| `home/modules/xdg-open-remote.nix` | Linux Home Manager module |
| `hosts/common/darwin-common.nix` | Launchd service definition |

## Security Considerations

- The listener only binds to `127.0.0.1` (localhost)
- SSH tunnel is encrypted
- Only URLs starting with `http://`, `https://`, or `file://` are accepted
- No authentication on the local socket (relies on localhost binding)
