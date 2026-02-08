# Restic Backup Administration Guide

This guide covers the restic backup module for nas-01, which provides multi-provider backup with ZFS snapshot support.

## Overview

The restic module (`services.clubcotton.restic`) provides:
- Multi-repository support (rsync.net, Backblaze B2, S3, etc.)
- ZFS snapshot-based consistent backups
- Per-repository retention policies
- Prometheus metrics exporter

## Current Configuration

**Repositories:**
- `rsyncnet` - Primary backup to rsync.net via SFTP
- `b2` - Secondary backup to Backblaze B2

**Backed up directories:**
- `/var/lib` - Service state data
- `/backups/postgresql` - Database dumps
- `/media/documents` - Documents
- `/media/tomcotton/data` - Tom's data
- `/media/tomcotton/audio-library/SFX_Library/My_Exports` - Audio exports

## Service Management

### Check backup status

```bash
# Timer status (when next backup runs)
systemctl status restic-backups-rsyncnet.timer
systemctl status restic-backups-b2.timer

# Last backup run
journalctl -u restic-backups-rsyncnet.service --since "1 day ago"
journalctl -u restic-backups-b2.service --since "1 day ago"
```

### Manually trigger backup

```bash
# rsync.net
sudo systemctl start restic-backups-rsyncnet.service
journalctl -u restic-backups-rsyncnet.service -f

# Backblaze B2
sudo systemctl start restic-backups-b2.service
journalctl -u restic-backups-b2.service -f
```

### Check Prometheus metrics

```bash
curl http://localhost:9997/metrics
```

## Repository Operations

### Set environment for manual restic commands

```bash
# For rsync.net
export RESTIC_REPOSITORY="sftp:de4729@de4729.rsync.net:restic-nas-01"
export RESTIC_PASSWORD_FILE="/run/agenix/restic-password"

# For B2
export RESTIC_REPOSITORY="b2:nas-01-restic-backup"
export RESTIC_PASSWORD_FILE="/run/agenix/restic-password"
source /run/agenix/restic-b2-env
```

### List snapshots

```bash
sudo restic snapshots
```

### Check repository health

```bash
sudo restic check
sudo restic check --read-data  # Full verification (slow)
```

### Show repository stats

```bash
sudo restic stats
sudo restic stats --mode raw-data  # Actual storage used
```

## Restoring Data

### Browse a snapshot

```bash
# List files in latest snapshot
sudo restic ls latest

# List specific path
sudo restic ls latest /var/lib/postgresql
```

### Restore files

```bash
# Restore to original location
sudo restic restore latest --target /

# Restore specific path to different location
sudo restic restore latest --target /tmp/restore --include /var/lib/postgresql

# Restore from specific snapshot
sudo restic restore 2cd5c360 --target /tmp/restore
```

### Mount snapshot for browsing

```bash
# Mount all snapshots
sudo mkdir -p /mnt/restic
sudo restic mount /mnt/restic

# In another terminal, browse:
ls /mnt/restic/snapshots/
ls /mnt/restic/snapshots/latest/

# Unmount when done
sudo umount /mnt/restic
```

## Secrets Management

### Required secrets

| Secret | Purpose | Location |
|--------|---------|----------|
| `restic-password` | Repository encryption password | `/run/agenix/restic-password` |
| `restic-b2-env` | B2 credentials | `/run/agenix/restic-b2-env` |
| `syncoid-ssh-key` | SSH key for rsync.net | `/run/agenix/syncoid-ssh-key` |

### Create/edit secrets

```bash
cd /path/to/nix-config/secrets

# Create restic password
agenix -e restic-password.age
# Enter a strong password

# Create B2 credentials
agenix -e restic-b2-env.age
# Contents:
# B2_ACCOUNT_ID=your_key_id
# B2_ACCOUNT_KEY=your_application_key
```

### Get B2 credentials

1. Log into [backblaze.com](https://www.backblaze.com)
2. Go to **Account** → **App Keys**
3. Create new application key or use master key
4. Copy `keyID` → `B2_ACCOUNT_ID`
5. Copy `applicationKey` → `B2_ACCOUNT_KEY`

## Maintenance

### Prune old snapshots

Pruning runs automatically after each backup based on retention policy. Manual prune:

```bash
sudo restic forget --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --keep-yearly 1
```

### Unlock stale locks

If a backup was interrupted, locks may remain:

```bash
sudo restic unlock
```

### Rebuild index

If repository has issues:

```bash
sudo restic rebuild-index
```

## ZFS Snapshot Integration

The module automatically:
1. Creates ZFS snapshots before backup (e.g., `rpool/local/lib@restic-rsyncnet-20260208-112001`)
2. Mounts snapshots read-only at `/mnt/.restic-snapshots/<repo>/<dataset>`
3. Backs up from the mounted snapshots (consistent point-in-time)
4. Unmounts and destroys snapshots after backup

### Check for orphaned snapshots

```bash
# Should be empty if no backup is running
zfs list -t snapshot | grep restic
```

### Clean up orphaned snapshots

```bash
# List restic snapshots
zfs list -t snapshot | grep restic

# Destroy if orphaned (no backup running)
zfs destroy rpool/local/lib@restic-rsyncnet-20260208-112001
```

## Troubleshooting

### SSH connection timeouts (rsync.net)

The module uses aggressive SSH settings to prevent timeouts:
- `ServerAliveInterval 15` - Send keepalive every 15s
- `ControlMaster auto` - Connection multiplexing
- `sftp.connections=2` - Limit parallel connections

If timeouts persist, check:
```bash
# Test SSH connectivity
ssh -v de4729@de4729.rsync.net

# Check SSH config is applied
cat /etc/ssh/ssh_config | grep -A10 rsync.net
```

### B2 authentication errors

```bash
# Verify credentials are loaded
cat /run/agenix/restic-b2-env

# Test B2 access
source /run/agenix/restic-b2-env
restic -r b2:nas-01-restic-backup snapshots
```

### Repository not initialized

```bash
# Initialize if needed (normally automatic)
sudo restic init
```

### Backup service failed

```bash
# Check logs
journalctl -u restic-backups-rsyncnet.service -n 100

# Check if ZFS snapshots are stuck
zfs list -t snapshot | grep restic

# Clean up and retry
sudo restic unlock
sudo systemctl start restic-backups-rsyncnet.service
```

## Configuration Reference

Configuration file: `hosts/nixos/nas-01/restic.nix`

### Key options

```nix
services.clubcotton.restic = {
  enable = true;

  sourceDirectories = [ "/var/lib" "/backups" ];  # Global paths
  excludePatterns = [ "*.pyc" "/var/cache" ];     # Global excludes

  repositories = {
    myrepo = {
      repository = "sftp:user@host:path";  # or b2:bucket, s3:url, etc.
      passwordFile = config.age.secrets.restic-password.path;
      environmentFile = null;  # For cloud credentials

      # Per-repo overrides (optional)
      paths = null;    # Override sourceDirectories
      exclude = null;  # Override excludePatterns

      timerConfig = {
        OnCalendar = "daily";
        Persistent = "true";
        RandomizedDelaySec = "1h";
      };

      retention = {
        keepDaily = 7;
        keepWeekly = 4;
        keepMonthly = 6;
        keepYearly = 1;
      };

      extraBackupArgs = [ "--exclude-caches" "--verbose" ];
      extraOptions = [ "sftp.connections=2" ];
    };
  };

  zfs = {
    enable = true;
    datasets = [ "rpool/local/lib" ];
    datasetMountPoints = { "rpool/local/lib" = "/var/lib"; };
  };

  prometheusExporter = {
    enable = true;
    port = 9997;
  };
};
```

## Comparison with Borgmatic

| Feature | Restic | Borgmatic/Borg |
|---------|--------|----------------|
| Native cloud support | Yes (S3, B2, etc.) | No (SFTP only) |
| Deduplication | Global | Per-repo |
| Encryption | AES-256-CTR | AES-256-CTR |
| Connection stability | Better (native backends) | SSH-dependent |
| Repository format | Content-addressable | Append-only |

Restic is preferred for cloud backends due to native API support, which avoids SSH timeout issues that plague borgmatic with rsync.net.
