# Cache Operations Reference

Quick reference for common cache and builder operations.

## Checking Cache Status

### Is the cache running?

```bash
ssh nas-01 systemctl status harmonia.service
```

### Is the cache accessible?

```bash
# Via Tailscale
curl http://nix-cache/nix-cache-info

# Direct
curl http://nas-01:5000/nix-cache-info

# From specific host
ssh some-host "curl http://nix-cache/nix-cache-info"
```

### Cache storage usage

```bash
# Dataset usage
ssh nas-01 "zfs list | grep nix-cache"

# Total store size
ssh nas-01 "du -sh /nix/store"

# Cache-specific (approximate)
ssh nas-01 "du -sh /ssdpool/local/nix-cache"
```

### Cache statistics

```bash
# Recent activity
ssh nas-01 "journalctl -u harmonia -n 100"

# Requests per minute
ssh nas-01 "journalctl -u harmonia --since '10 minutes ago' | grep -c GET"

# Service uptime
ssh nas-01 "systemctl status harmonia | grep Active"
```

---

## Managing Builders

### List configured builders

```bash
ssh nas-01 "nix show-config | grep builders"
```

### Test SSH to a builder

```bash
ssh nas-01
ssh -i /run/agenix/nix-builder-ssh-key nix-builder@builder-host 'nix-store --version'
```

### Test remote build on specific builder

```bash
ssh nas-01
nix-build '<nixpkgs>' -A hello \
  --builders 'ssh://nix-builder@nix-01 x86_64-linux' \
  --max-jobs 1 \
  -v
```

### Check builder load

```bash
# All builders
for host in nix-01 nix-02 nix-03; do
  echo "=== $host ==="
  ssh $host "uptime"
done

# Specific builder
ssh nix-01 "top -bn1 | head -5"
```

### Verify builder is receiving jobs

```bash
# On builder, watch for builds
ssh nix-01 "journalctl -u nix-daemon -f"

# On coordinator, trigger build
ssh nas-01 "nix-build '<nixpkgs>' -A hello -v"
```

---

## Cache Maintenance

### Restart Harmonia

```bash
ssh nas-01 "systemctl restart harmonia.service"
```

### View Harmonia logs

```bash
# Last 50 lines
ssh nas-01 "journalctl -u harmonia -n 50"

# Follow logs live
ssh nas-01 "journalctl -u harmonia -f"

# Errors only
ssh nas-01 "journalctl -u harmonia -p err"
```

### Garbage collect cache

```bash
# Standard (30 days)
ssh nas-01 "nix-collect-garbage --delete-older-than 30d"

# Aggressive (7 days)
ssh nas-01 "nix-collect-garbage --delete-older-than 7d"

# Check what would be deleted (dry run)
ssh nas-01 "nix-collect-garbage --delete-older-than 30d --dry-run"
```

### Verify cache integrity

```bash
# Check for corrupted store paths
ssh nas-01 "nix-store --verify --check-contents"

# Repair if needed
ssh nas-01 "nix-store --verify --check-contents --repair"
```

### Re-sign store paths

```bash
# Sign specific path
ssh nas-01 "nix store sign --key-file /run/agenix/harmonia-signing-key /nix/store/HASH-package"

# Sign all current store paths (slow!)
ssh nas-01 "nix store sign --key-file /run/agenix/harmonia-signing-key --all"
```

---

## Secrets Management

### View current public key

```bash
cat secrets/cache-public-key.txt
```

### Extract public key from secret

```bash
cd secrets/
agenix -d harmonia-signing-key.age | cut -d: -f2
```

### Verify secrets are encrypted

```bash
cd secrets/
./verify-secrets.sh
```

### Regenerate all secrets

```bash
cd secrets/
./regenerate-nix-cache-secrets.sh
```

After regenerating:
1. Update `modules/nix-builder/client.nix` with new public key
2. Deploy to nas-01: `just switch nas-01`
3. Deploy to all clients: `just deploy-all`

---

## Client Operations

### Check if host is using cache

```bash
# On any host
nix show-config | grep substituters
# Should show: http://nix-cache https://cache.nixos.org

nix show-config | grep trusted-public-keys
# Should show: nas-01-cache:...
```

### Test cache from client

```bash
# Test connectivity
curl http://nix-cache/nix-cache-info

# Try fetching a package
nix-build '<nixpkgs>' -A hello --dry-run
```

### Force cache refresh on client

```bash
# Clear local cache
nix-store --gc

# Rebuild with verbose output
nix-build '<nixpkgs>' -A hello -v
```

### Manually specify cache

```bash
# Override cache for single build
nix-build '<nixpkgs>' -A hello \
  --option substituters "http://nix-cache https://cache.nixos.org" \
  --option trusted-public-keys "nas-01-cache:... cache.nixos.org-1:..."
```

---

## Performance Monitoring

### Check build distribution

```bash
# Watch builds in real-time on nas-01
ssh nas-01 "journalctl -u nix-daemon -f | grep 'building.*on ssh'"
```

### Monitor cache network usage

```bash
# On nas-01
ssh nas-01 "iftop -i tailscale0"

# Or with nload
ssh nas-01 "nload tailscale0"
```

### ZFS performance

```bash
# I/O stats for cache dataset
ssh nas-01 "zpool iostat -v ssdpool 1 5"

# ARC hit rate
ssh nas-01 "arcstat 1 5"
```

### Harmonia performance

```bash
# Thread count
ssh nas-01 "ps -eLf | grep harmonia | wc -l"

# Memory usage
ssh nas-01 "ps aux | grep harmonia"

# Open connections
ssh nas-01 "ss -tnp | grep ':5000'"
```

---

## Troubleshooting Commands

### Cache not responding

```bash
# Check service status
ssh nas-01 "systemctl status harmonia.service"

# Check if port is listening
ssh nas-01 "ss -tlnp | grep :5000"

# Check firewall
ssh nas-01 "iptables -L | grep 5000"

# Check Tailscale
ssh nas-01 "tailscale status | grep nix-cache"
```

### Builds not distributed

```bash
# Check coordinator config
ssh nas-01 "nix show-config | grep -A 10 builders"

# Test SSH to all builders
for host in nix-01 nix-02 nix-03; do
  echo "Testing $host..."
  ssh nas-01 "ssh -i /run/agenix/nix-builder-ssh-key nix-builder@$host echo OK"
done

# Check builder nix-daemon
ssh nix-01 "systemctl status nix-daemon"
```

### Client not using cache

```bash
# On client, check config
nix show-config | grep -E '(substituters|trusted-public-keys)'

# Test cache access
curl -v http://nix-cache/nix-cache-info

# Check Tailscale
tailscale status

# Try direct IP
curl http://192.168.5.300:5000/nix-cache-info
```

### Cache signature issues

```bash
# On client, check trusted keys
nix show-config | grep trusted-public-keys

# On nas-01, check signing key
ssh nas-01 "agenix -d /run/agenix/harmonia-signing-key"

# Compare public keys
cat secrets/cache-public-key.txt
nix show-config | grep nas-01-cache
```

---

## Emergency Procedures

### Cache server down - bypass cache

On any host, temporarily disable cache:

```bash
# One-time build without cache
nix-build --option substituters "https://cache.nixos.org"

# Or edit /etc/nix/nix.conf and remove http://nix-cache
```

### Corrupted cache - rebuild

```bash
ssh nas-01

# Stop Harmonia
systemctl stop harmonia.service

# Clear cache metadata
rm -rf /ssdpool/local/nix-cache/*

# Verify store
nix-store --verify --check-contents --repair

# Start Harmonia
systemctl start harmonia.service

# Populate cache with common packages
nix-build '<nixpkgs>' -A hello firefox
```

### Builder stuck - kill jobs

```bash
# On problematic builder
ssh builder-host

# Find stuck builds
ps aux | grep nix-build

# Kill them
pkill -9 -f nix-build

# Restart nix-daemon
systemctl restart nix-daemon
```

### Lost public key - extract

```bash
cd secrets/

# Decrypt and show key
agenix -d harmonia-signing-key.age

# Save to reference file
agenix -d harmonia-signing-key.age | cut -d: -f2 > cache-public-key.txt
```

---

## Health Check Script

Save this as `check-cache-health.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Cache Server Health Check ==="
echo ""

echo "1. Harmonia service:"
ssh nas-01 "systemctl is-active harmonia.service" && echo "  ✓ Running" || echo "  ✗ Not running"

echo ""
echo "2. Cache accessibility:"
curl -sf http://nix-cache/nix-cache-info > /dev/null && echo "  ✓ Accessible" || echo "  ✗ Not accessible"

echo ""
echo "3. Cache storage:"
ssh nas-01 "zfs list -Ho used,avail ssdpool/local/nix-cache" | awk '{printf "  Used: %s / Available: %s\n", $1, $2}'

echo ""
echo "4. Builder connectivity:"
for host in nix-01 nix-02 nix-03; do
  if ssh nas-01 "timeout 5 ssh -i /run/agenix/nix-builder-ssh-key nix-builder@$host echo OK" > /dev/null 2>&1; then
    echo "  ✓ $host"
  else
    echo "  ✗ $host"
  fi
done

echo ""
echo "5. Recent cache activity:"
count=$(ssh nas-01 "journalctl -u harmonia --since '1 hour ago' | grep -c GET || true")
echo "  $count requests in last hour"

echo ""
echo "=== Health Check Complete ==="
```

Make it executable:
```bash
chmod +x check-cache-health.sh
./check-cache-health.sh
```

---

## See Also

- [BUILD_AND_CACHE.md](./BUILD_AND_CACHE.md) - Complete documentation
- [QUICK_START_CACHE.md](./QUICK_START_CACHE.md) - Quick start guide
- [../secrets/README-NIX-CACHE.md](../secrets/README-NIX-CACHE.md) - Secrets management
