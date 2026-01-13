# Remote Notification System

Send macOS notifications from remote Linux hosts via SSH reverse port forwarding.

## Overview

When working on remote Linux hosts via SSH, you often want to send notifications to your local Mac (e.g., when a long-running build completes, tests finish, etc.). This feature tunnels those notification requests back to your Mac.

## Architecture

```
┌─────────────────┐         SSH Tunnel          ┌─────────────────┐
│   Linux Host    │    RemoteForward 7892       │      Mac        │
│                 │ ◄──────────────────────────►│                 │
│  remote-notify  │         localhost:7892      │notification-receiver│
│    (client)     │                             │   (listener)    │
└─────────────────┘                             └─────────────────┘
        │                                               │
        │ sends title/message                           │ displays
        ▼                                               ▼
   remote-notify -t "Build" -m "Done"           osascript notification
```

1. **Mac**: `notification-receiver` daemon listens on `localhost:7892`
2. **SSH**: `RemoteForward 7892 localhost:7892` tunnels the port to remote hosts
3. **Linux**: `remote-notify` sends notification data through the tunnel
4. **Mac**: Notification appears via macOS notification system

## Components

### notification-receiver (macOS)

A launchd service that:
- Listens on TCP port 7892 using socat
- Receives notification data (title, message, optional subtitle)
- Displays **persistent alerts** using `osascript display alert` (stays on screen until dismissed)
- Logs to `/tmp/notification-receiver.log`

**Package**: `pkgs/notification-receiver/`
**Module**: `home/modules/notification-receiver.nix`
**Service**: Defined in `hosts/common/darwin-common.nix`

### remote-notify (Linux)

A shell script that:
- Accepts notification parameters via flags
- Checks if SSH tunnel is available
- Sends notification through tunnel if available
- Falls back to local `notify-send` if tunnel unavailable

**Package**: `pkgs/remote-notify/`
**Module**: `home/modules/remote-notify.nix`

## Configuration

### Enabling (already done in bcotton.nix)

```nix
# Automatically enabled based on platform
programs.notification-receiver.enable = pkgs.stdenv.isDarwin;
programs.remote-notify.enable = pkgs.stdenv.isLinux;
```

### SSH RemoteForward

Configured in `home/bcotton.nix`:

```nix
programs.ssh = {
  extraConfig = ''
    Host admin condo-01 natalya-01 nas-01 nix-01 nix-02 nix-03 nix-04 imac-01 imac-02 dns-01 octoprint frigate-host
      RemoteForward 7892 localhost:7892
  '';
};
```

### Environment Variables

| Variable | Set On | Purpose |
|----------|--------|---------|
| `REMOTE_NOTIFY_PORT` | Linux | Port for tunnel (default: 7892) |

## Usage

### Basic Usage

```bash
# On any Linux host (after SSH with RemoteForward)
remote-notify -t "Build Complete" -m "All tests passed"

# With subtitle
remote-notify -t "CI Pipeline" -m "Deployed successfully" -s "nix-01"

# Pipe message from command output
echo "Long build output..." | remote-notify -t "Build Log"

# Notify when a command finishes
make build && remote-notify -t "Build" -m "Success" || remote-notify -t "Build" -m "Failed"
```

### Command Line Options

```
Usage: remote-notify -t TITLE -m MESSAGE [-s SUBTITLE]
       command | remote-notify -t TITLE [-s SUBTITLE]

Options:
  -t TITLE     Notification title (required)
  -m MESSAGE   Notification message (or read from stdin if not provided)
  -s SUBTITLE  Notification subtitle (optional)
  -h, --help   Show this help message
```

### Tmux Sessions

The feature works with tmux reconnection:
- `REMOTE_NOTIFY_PORT` is exported in shell environment
- Notifications work after detach/reattach

### Verifying the Setup

**On Mac:**
```bash
# Check if service is running
launchctl list | grep notification-receiver

# Check if port is listening
lsof -i :7892

# Test manually
echo -e "Test Title\nTest Message" | nc localhost 7892
```

**On Linux (via SSH):**
```bash
# Check if tunnel is active
ss -tln | grep 7892

# Test the remote notification
remote-notify -t "Test" -m "Hello from remote!"

# Check environment
echo $REMOTE_NOTIFY_PORT
```

## Troubleshooting

### Notification not appearing on Mac

1. Check if service is running:
   ```bash
   launchctl list | grep notification-receiver
   ```

2. Check logs:
   ```bash
   tail -f /tmp/notification-receiver.log
   tail -f /tmp/notification-receiver.error.log
   ```

3. Restart the service:
   ```bash
   launchctl unload ~/Library/LaunchAgents/org.nixos.notification-receiver.plist
   launchctl load ~/Library/LaunchAgents/org.nixos.notification-receiver.plist
   ```

### Tunnel not working

1. Verify SSH was started with RemoteForward:
   ```bash
   # On Linux host
   ss -tln | grep 7892
   ```

2. Check if another SSH session is using the port (first connection wins)

3. Manually test the tunnel:
   ```bash
   # On Linux
   echo -e "Test\nMessage" | timeout 5 bash -c 'cat > /dev/tcp/127.0.0.1/7892'
   ```

### remote-notify falls back to notify-send

This is expected behavior when the tunnel is not available. Check:
- SSH session includes the RemoteForward
- No other process is using port 7892

### Multiple SSH sessions

Only the first SSH connection's RemoteForward will succeed. Subsequent connections to the same host won't be able to bind port 7892. This is a limitation of the approach.

**Workaround**: Use a single SSH session with tmux for persistent work.

## Files

| File | Purpose |
|------|---------|
| `pkgs/notification-receiver/default.nix` | Mac listener package |
| `pkgs/notification-receiver/notification-receiver.sh` | Listener script |
| `pkgs/remote-notify/default.nix` | Linux client package |
| `pkgs/remote-notify/remote-notify.sh` | Client script |
| `home/modules/notification-receiver.nix` | Mac Home Manager module |
| `home/modules/remote-notify.nix` | Linux Home Manager module |
| `hosts/common/darwin-common.nix` | Launchd service definition |

## Security Considerations

- The listener only binds to `127.0.0.1` (localhost)
- SSH tunnel is encrypted
- Text-only (no code execution from notification content)
- No authentication on the local socket (relies on localhost binding)

## Related

- [REMOTE_BROWSER.md](REMOTE_BROWSER.md) - Similar system for opening URLs
- [REMOTE_CLIPBOARD.md](REMOTE_CLIPBOARD.md) - Similar system for clipboard sync
