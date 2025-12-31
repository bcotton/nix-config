# Safe Network Configuration Scripts

This directory contains utility scripts for safely managing network configuration changes.

## safe-network-switch.sh

A safety wrapper for applying NixOS network configuration changes with automatic rollback on failure.

### Purpose

When making network configuration changes, especially to remote systems, a misconfiguration can lock you out and require physical console access. This script prevents that by:

1. Testing baseline network connectivity
2. Applying the new configuration
3. Testing the new network configuration
4. Requiring user confirmation within a timeout
5. Automatically rolling back if tests fail or confirmation times out

### Usage

**On the target host** (the one being configured):

```bash
# Using just command
sudo just safe-network-switch

# Direct script execution
sudo ./scripts/safe-network-switch.sh
```

**Important**: This script must be run **locally on the host being configured**, not remotely. If you're changing network config on a remote host, you should:

1. SSH to the remote host
2. `cd` to the nix-config directory
3. Make your configuration changes (edit files)
4. Run `sudo just safe-network-switch`

### How It Works

#### 1. Baseline Testing
Before applying any changes, the script tests your current network to ensure the baseline is working:
- Network interfaces are up
- Gateway is reachable
- DNS is reachable
- External connectivity works

#### 2. Configuration Application
Runs `just switch` to apply your NixOS configuration changes.

#### 3. Network Testing
After applying the configuration, the script performs the same connectivity tests:
- Tests are retried up to 3 times (configurable)
- 2-second intervals between retries
- If any test fails, immediate rollback occurs

#### 4. User Confirmation
If tests pass, you have 60 seconds (configurable) to confirm the network is working:
- Press **'y'** to keep the new configuration
- Press **'n'** to rollback immediately
- Wait for timeout to automatically rollback

This confirmation step is crucial because automated tests can't catch everything (e.g., specific service connectivity, VLAN-specific issues, etc.).

#### 5. Automatic Rollback
If tests fail or you don't confirm in time:
- Automatically switches back to the previous NixOS generation
- Ensures you don't get locked out

### Environment Variables

Customize behavior with environment variables:

```bash
# Change confirmation timeout (default: 60 seconds)
export SAFE_NETWORK_TIMEOUT=120
sudo just safe-network-switch

# Change number of test retries (default: 3)
export SAFE_NETWORK_RETRIES=5

# Change interval between retries (default: 2 seconds)
export SAFE_NETWORK_INTERVAL=3
```

### Example Session

```bash
$ sudo just safe-network-switch
⚠️  This command applies config and tests network connectivity
⚠️  It will automatically rollback if network tests fail

[INFO] ================================================
[INFO] Safe Network Configuration Switch
[INFO] ================================================

[INFO] Detecting network configuration...
[INFO] Gateway: 192.168.5.1
[INFO] DNS: 192.168.5.220

[INFO] Testing current network configuration as baseline...
[INFO] Network test attempt 1/3
[INFO]   Checking network interfaces...
[SUCCESS]   Network interfaces are UP
[INFO]   Testing gateway connectivity (192.168.5.1)...
[SUCCESS]   Gateway is reachable
[INFO]   Testing DNS resolution...
[SUCCESS]   DNS server is reachable
[INFO]   Testing external connectivity...
[SUCCESS]   External connectivity working
[SUCCESS] Baseline network test passed

[INFO] Applying new configuration with 'just switch'...

building the system configuration...
activating the configuration...
setting up /etc...
reloading systemd...

[SUCCESS] Configuration applied successfully
[INFO] New system generation: 42
[INFO] Waiting 5 seconds for network to stabilize...

[INFO] Testing new network configuration...
[INFO] Network test attempt 1/3
[INFO]   Checking network interfaces...
[SUCCESS]   Network interfaces are UP
[INFO]   Testing gateway connectivity (192.168.5.1)...
[SUCCESS]   Gateway is reachable
[INFO]   Testing DNS resolution...
[SUCCESS]   DNS server is reachable
[INFO]   Testing external connectivity...
[SUCCESS]   External connectivity working
[INFO]   Checking systemd-networkd status...
[SUCCESS]   Network is routable

[SUCCESS] All network tests passed!

[WARNING]
[WARNING] ==============================================
[WARNING] Network configuration has been applied!
[WARNING] ==============================================
[WARNING]
[WARNING] You have 60 seconds to confirm the network is working.
[WARNING] If you don't respond, the system will automatically rollback.
[WARNING]
[INFO] Press 'y' to keep the new configuration
[INFO] Press 'n' to rollback immediately
[WARNING]
Time remaining: 58s  y

[SUCCESS] Configuration confirmed by user
[SUCCESS]
[SUCCESS] ================================================
[SUCCESS] Configuration change completed successfully!
[SUCCESS] ================================================
[SUCCESS]
[SUCCESS] New generation: 42
[INFO] Previous generation 41 is still available for rollback
[INFO] To manually rollback: sudo nixos-rebuild switch --rollback
```

### Failure Example

If network tests fail:

```bash
[INFO] Testing new network configuration...
[INFO] Network test attempt 1/3
[INFO]   Checking network interfaces...
[SUCCESS]   Network interfaces are UP
[INFO]   Testing gateway connectivity (192.168.5.1)...
[ERROR]   Cannot reach gateway 192.168.5.1
[WARNING] Test failed, waiting 2s before retry...

[INFO] Network test attempt 2/3
[INFO]   Checking network interfaces...
[SUCCESS]   Network interfaces are UP
[INFO]   Testing gateway connectivity (192.168.5.1)...
[ERROR]   Cannot reach gateway 192.168.5.1
[WARNING] Test failed, waiting 2s before retry...

[INFO] Network test attempt 3/3
[INFO]   Checking network interfaces...
[SUCCESS]   Network interfaces are UP
[INFO]   Testing gateway connectivity (192.168.5.1)...
[ERROR]   Cannot reach gateway 192.168.5.1

[ERROR]
[ERROR] Network tests failed after 3 attempts!
[ERROR] Automatically rolling back to previous configuration...
[ERROR]

[WARNING] Rolling back to generation 41...
stopping the following units: systemd-networkd.service
activating the configuration...
setting up /etc...
reloading systemd...
starting the following units: systemd-networkd.service

[SUCCESS] Successfully rolled back to generation 41
[SUCCESS] System rolled back successfully
[INFO] Please check your network configuration and try again
```

### What Gets Tested

The script performs comprehensive network testing:

1. **Interface Status**: Checks if network interfaces are UP
2. **Gateway Connectivity**: Pings default gateway
3. **DNS Connectivity**: Pings DNS server
4. **External Connectivity**: Pings 8.8.8.8 (warning if fails)
5. **systemd-networkd Status**: Checks network is routable (if using systemd-networkd)

### When to Use This Script

**Use this script when**:
- Changing network interface configuration (bonding, bridges, etc.)
- Modifying VLAN settings
- Updating systemd-networkd configuration
- Changing IP addresses or routing
- Making any networking changes that could lock you out

**Don't need this script when**:
- Adding firewall rules (firewall permits SSH by default)
- Installing packages
- Changing non-network services
- You have physical console access readily available

### Limitations

The script cannot test:
- Specific service accessibility (e.g., if a particular port is accessible)
- VLAN-specific connectivity beyond the host's direct access
- Complex routing scenarios
- Bandwidth or performance issues

Always **manually verify** critical services after confirming the configuration.

### Recovery from Script Failure

If the script itself fails to rollback (very rare):

```bash
# List generations
sudo nix-env -p /nix/var/nix/profiles/system --list-generations

# Rollback to previous
sudo nixos-rebuild switch --rollback

# Or switch to specific generation
sudo nix-env -p /nix/var/nix/profiles/system --switch-generation 41
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

### Manual Testing Commands

If you want to manually test network connectivity:

```bash
# Check interfaces
ip link show
networkctl list

# Check addresses
ip addr show

# Test gateway
ping -c 2 192.168.5.1

# Test DNS
ping -c 2 192.168.5.220

# Check routing
ip route show

# Check systemd-networkd
networkctl status
systemctl status systemd-networkd
```

## Integration with Remote Management

For safer remote deployments:

1. **Test locally first**:
   ```bash
   # On your workstation, build the config for the remote host
   just build nas-01

   # If build succeeds, SSH to the host
   ssh root@nas-01

   # On the remote host, sync the config and run safe switch
   cd /path/to/nix-config
   git pull
   sudo just safe-network-switch
   ```

2. **Use tmux/screen**:
   ```bash
   ssh root@nas-01
   tmux new -s deploy
   cd /path/to/nix-config
   sudo just safe-network-switch
   # Even if SSH disconnects, tmux session continues
   ```

3. **Keep a backup connection**:
   - If the host has multiple IPs (e.g., Tailscale + local)
   - Keep one SSH session open via Tailscale
   - Apply changes via local network SSH
   - If local network fails, you still have Tailscale access

## Best Practices

1. **Always test locally first** if the hosts have identical network config
2. **Use version control**: Commit working configs before experimenting
3. **Change one thing at a time**: Don't combine network changes with other major changes
4. **Have a rollback plan**: Know how to revert changes manually
5. **Schedule changes**: During maintenance windows, not production hours
6. **Document expected behavior**: Know what "working" means for your specific setup

## See Also

- `docs/NETWORKING.md` - Complete networking architecture documentation
- `modules/systemd-network/README.md` - systemd-networkd module documentation
