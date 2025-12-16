# Borgmatic Backup Service

This module provides a NixOS configuration wrapper for borgmatic backups, following the clubcotton service pattern. It's designed for backing up to rsync.net or any other borg-compatible repository.

## Basic Usage

```nix
{
  services.clubcotton.borgmatic = {
    enable = true;

    # Directories to backup
    sourceDirectories = [
      "/var/lib"
      "/home"
      "/etc"
    ];

    # Repository configuration (rsync.net example)
    repositories = [
      {
        path = "ssh://12345@ch-s011.rsync.net/./backups/my-hostname";
        label = "rsync.net";
      }
    ];

    # Encryption (required for rsync.net)
    encryption = {
      mode = "repokey-blake2";  # Recommended for rsync.net
      passphraseFile = config.age.secrets.borg-passphrase.path;
    };

    # SSH configuration for rsync.net
    sshCommand = "ssh -i /root/.ssh/id_ed25519_rsyncnet";

    # Retention policy
    retention = {
      keepDaily = 7;
      keepWeekly = 4;
      keepMonthly = 6;
      keepYearly = 1;
    };

    # Exclude patterns
    excludePatterns = [
      "*.pyc"
      "__pycache__"
      "/var/cache"
      "/var/tmp"
      "*/node_modules"
      "*/.cache"
    ];
  };
}
```

## Advanced Configuration

### PostgreSQL Database Backups

```nix
{
  services.clubcotton.borgmatic = {
    enable = true;
    
    sourceDirectories = [ "/etc" "/var/lib/important" ];
    
    repositories = [
      {
        path = "ssh://user@server.rsync.net/./backups";
        label = "rsync.net";
      }
    ];
    
    encryption = {
      mode = "repokey-blake2";
      passphraseFile = config.age.secrets.borg-passphrase.path;
    };

    # Backup all PostgreSQL databases
    postgresqlDatabases = [
      {
        name = "all";
        username = "postgres";
      }
      # Or specific databases:
      # {
      #   name = "myapp";
      #   hostname = "localhost";
      #   port = 5432;
      #   username = "dbuser";
      # }
    ];
  };
}
```

### ZFS Snapshot Backups

Borgmatic can automatically create ZFS snapshots before backing up, ensuring consistent backups of ZFS datasets. Simply enable ZFS support and specify your dataset mount points in `sourceDirectories`:

```nix
{
  services.clubcotton.borgmatic = {
    enable = true;
    
    # Specify mount points of ZFS datasets you want to backup
    sourceDirectories = [
      "/var/lib"        # If this is a ZFS dataset, it will be snapshotted
      "/home"           # If this is a ZFS dataset, it will be snapshotted
      "/mnt/photos"     # If this is a ZFS dataset, it will be snapshotted
    ];
    
    repositories = [
      {
        path = "ssh://user@server.rsync.net/./backups";
        label = "rsync.net";
      }
    ];
    
    encryption = {
      mode = "repokey-blake2";
      passphraseFile = config.age.secrets.borg-passphrase.path;
    };

    # Enable ZFS snapshot support
    zfs.enable = true;

    retention = {
      keepDaily = 7;
      keepWeekly = 4;
      keepMonthly = 6;
      keepYearly = 1;
    };
  };
}
```

#### How ZFS Discovery Works

Borgmatic automatically discovers ZFS datasets in two ways:

1. **From sourceDirectories**: Borgmatic looks at each path in your `sourceDirectories` and checks if it (or its parent directories) is a ZFS dataset. For example:
   - If you specify `/var/lib` and `/var` is a ZFS dataset, borgmatic will snapshot `/var`
   - Works with nested datasets - borgmatic selects the "closest" parent dataset

2. **User Property**: You can also mark specific datasets with a borgmatic property. This is especially useful for datasets with legacy mount points:
   ```nix
   zfs.datasets = [
     "rpool/local/lib"
     "rpool/safe/home"
   ];
   ```
   This automatically sets `org.torsion.borgmatic:backup=auto` on those datasets.
   
   Or manually via command line:
   ```bash
   zfs set org.torsion.borgmatic:backup=auto rpool/local/lib
   ```

#### ZFS Snapshot Behavior

When ZFS support is enabled, borgmatic will:
- Create temporary snapshots of discovered datasets before backup
- Temporarily mount the snapshots (in borgmatic's runtime directory)
- Back up from the snapshots (ensuring consistency)
- Automatically destroy the temporary snapshots after backup
- Store files in the archive at their original paths (e.g., `/var/lib`, not the snapshot path)

#### Advanced ZFS Configuration

```nix
{
  services.clubcotton.borgmatic = {
    enable = true;
    
    sourceDirectories = [ "/var/lib" "/home" ];
    
    repositories = [{
      path = "ssh://user@server.rsync.net/./backups";
      label = "rsync.net";
    }];
    
    encryption = {
      mode = "repokey-blake2";
      passphraseFile = config.age.secrets.borg-passphrase.path;
    };

    # ZFS configuration with custom commands and explicit datasets
    zfs = {
      enable = true;
      
      # Explicitly mark datasets for backup (useful for legacy mount points)
      datasets = [
        "rpool/local/lib"
        "rpool/safe/home"
      ];
      
      # Optional: custom command paths
      zfsCommand = "/usr/local/bin/zfs";      # Optional: custom zfs binary
      mountCommand = "/usr/local/bin/mount";  # Optional: custom mount binary
      umountCommand = "/usr/local/bin/umount"; # Optional: custom umount binary
    };
  };
}
```

For more details, see the [borgmatic ZFS documentation](https://torsion.org/borgmatic/reference/configuration/data-sources/zfs/).

### Hooks for Custom Actions

```nix
{
  services.clubcotton.borgmatic = {
    enable = true;
    
    # ... other config ...
    
    beforeBackupHooks = [
      "echo 'Starting backup at $(date)'"
      "systemctl stop myservice"
    ];
    
    afterBackupHooks = [
      "systemctl start myservice"
      "echo 'Backup completed successfully at $(date)'"
    ];
    
    onErrorHooks = [
      "echo 'Backup failed!' | mail -s 'Backup Error' admin@example.com"
    ];
  };
}
```

### Multiple Repositories

```nix
{
  services.clubcotton.borgmatic = {
    enable = true;
    
    sourceDirectories = [ "/var/lib" "/home" ];
    
    # Backup to multiple locations
    repositories = [
      {
        path = "ssh://user@server.rsync.net/./backups/primary";
        label = "rsync.net";
      }
      {
        path = "/mnt/external-drive/backups";
        label = "local";
      }
    ];
    
    encryption = {
      mode = "repokey-blake2";
      passphraseFile = config.age.secrets.borg-passphrase.path;
    };
  };
}
```

### Custom Borgmatic Configuration

For advanced options not covered by the module, use `extraConfig`:

```nix
{
  services.clubcotton.borgmatic = {
    enable = true;
    
    # ... basic config ...
    
    extraConfig = {
      # Add healthcheck monitoring
      healthchecks = {
        ping_url = "https://hc-ping.com/your-uuid";
      };
      
      # Custom archive patterns
      patterns = [
        "R /var/lib"
        "+ /var/lib/important"
        "- /var/lib/cache"
      ];
      
      # Umask for file permissions
      umask = "0077";
    };
  };
}
```

## Monitoring with Prometheus

Borgmatic includes a Prometheus exporter that exposes metrics about your backups, allowing you to monitor backup health and set up alerts.

### Enable the Exporter

```nix
{
  services.clubcotton.borgmatic = {
    enable = true;
    
    # Enable Prometheus metrics
    prometheusExporter = {
      enable = true;
      port = 9996;  # Optional, defaults to 9996
    };
    
    # ... rest of your borgmatic config ...
  };
}
```

### Prometheus Scrape Configuration

The module automatically configures Prometheus to scrape borgmatic metrics when the exporter is enabled. The following job is added:

```yaml
- job_name: borgmatic
  static_configs:
    - targets: ['localhost:9996']
```

### Available Metrics

The exporter provides the following key metrics:

- `borg_last_backup_timestamp` - Unix timestamp of the last successful backup
- `borg_backup_duration_seconds` - Duration of the last backup in seconds
- `borg_backup_size_bytes` - Size of the last backup
- `borg_repository_size_bytes` - Total size of the repository
- `borg_backup_files_count` - Number of files in the last backup

### Alert Rules

The module includes an alert that fires when backups haven't run recently:

```yaml
- alert: BorgmaticMissingBackup
  expr: time() - borg_last_backup_timestamp{job="borgmatic"} > 90000
  for: 1m
  labels:
    severity: warning
  annotations:
    summary: "Borg missing backup"
    description: "The instance {{ $labels.instance }} has not created a backup 
                  of the repo {{ $labels.repository }} in the last 25 hours"
```

This alert triggers if a backup hasn't completed in the last 90000 seconds (25 hours), giving some buffer for daily backups.

### Viewing Metrics

You can view the raw metrics by accessing the exporter endpoint:

```bash
curl http://localhost:9996/metrics
```

Or query them through Prometheus/Grafana for visualization and alerting.

### Grafana Dashboard

A pre-built Grafana dashboard for visualizing borgmatic backups is automatically provisioned when using the Grafana module. The dashboard (ID: 20334) shows:

- Backup status and last run time
- Repository size trends
- Backup duration
- Success/failure status
- Archive counts

The dashboard is available at: `https://grafana.com/grafana/dashboards/20334-borgmatic-backups/`

Access it in your Grafana instance under **Dashboards → Borgmatic Backups**.

## rsync.net Setup

1. **Create SSH key for borg backups:**
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_rsyncnet -C "borg-backup"
   ```

2. **Add the public key to rsync.net:**
   ```bash
   cat ~/.ssh/id_ed25519_rsyncnet.pub | ssh your-account@server.rsync.net "cat >> .ssh/authorized_keys"
   ```
4. **Initialize the repository (first time only):**
   ```bash
   borgmatic init  --encryption=repokey-blake2
   ```

  5. Get info on the remote: 
  ```bash
     borgmatic info
  ```


## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable the borgmatic service |
| `sourceDirectories` | list of strings | [] | Directories to backup |
| `repositories` | list of submodules | [] | Borg repositories to backup to |
| `encryption.mode` | enum | "repokey-blake2" | Encryption mode |
| `encryption.passphraseFile` | path | null | File containing passphrase |
| `retention.keepDaily` | int | 7 | Daily archives to keep |
| `retention.keepWeekly` | int | 4 | Weekly archives to keep |
| `retention.keepMonthly` | int | 6 | Monthly archives to keep |
| `retention.keepYearly` | int | 1 | Yearly archives to keep |
| `compression` | string | "auto,zstd" | Compression algorithm |
| `excludePatterns` | list of strings | [] | Patterns to exclude |
| `excludeCaches` | bool | true | Exclude cache directories |
| `oneFileSystem` | bool | false | Stay within one filesystem |
| `archiveNameFormat` | string | "{hostname}-{now:%Y-%m-%dT%H:%M:%S}" | Archive naming format |
| `sshCommand` | string | null | Custom SSH command |
| `remotePath` | string | null | Path to borg binary on remote server |
| `checks` | list of enums | ["repository", "archives"] | Consistency checks to run |
| `checkLast` | int | 3 | Number of recent archives to check |
| `beforeBackupHooks` | list of strings | [] | Commands to run before backup |
| `afterBackupHooks` | list of strings | [] | Commands to run after backup |
| `onErrorHooks` | list of strings | [] | Commands to run on error |
| `postgresqlDatabases` | list of submodules | [] | PostgreSQL databases to backup |
| `zfs.enable` | bool | false | Enable ZFS snapshot support |
| `zfs.datasets` | list of strings | [] | ZFS datasets to mark for backup |
| `zfs.zfsCommand` | string | null | Custom zfs command path |
| `zfs.mountCommand` | string | null | Custom mount command path |
| `zfs.umountCommand` | string | null | Custom umount command path |
| `extraConfig` | attrs | {} | Additional borgmatic options |
| `verbosity` | int | 0 | Verbosity level (-2 to 2) |
| `prometheusExporter.enable` | bool | false | Enable Prometheus exporter |
| `prometheusExporter.port` | int | 9996 | Prometheus exporter port |

## Systemd Timer

The service runs on a systemd timer (configured by the upstream borgmatic package). To check the schedule:

```bash
systemctl list-timers borgmatic
```

To manually trigger a backup:

```bash
systemctl start borgmatic
```

To view logs:

```bash
journalctl -u borgmatic -f
```

## References

- [Borgmatic Documentation](https://torsion.org/borgmatic/docs/reference/configuration/)
- [Borg Documentation](https://borgbackup.readthedocs.io/)
- [rsync.net Borg Guide](https://www.rsync.net/products/borg.html)

## Administration Commands

### Checking Your Backups
These commands need to be run as `root`, as the ssh keys and borg encryption key are stored in agenix.

View information about your repository:

```bash
# Get repository info (size, encryption type, etc.)
borgmatic info

# Get detailed info about a specific repository
borgmatic info --repository rsync.net

# List all archives in the repository
borgmatic list

# List files in a specific archive
borgmatic list --archive nas-01-2025-12-10T12:00:00

# Check repository and archive consistency
borgmatic check

# Do a full data integrity check (slower, verifies all data)
borgmatic check --force
```

### Viewing Archive Contents

```bash
# List all archives with dates and sizes
borgmatic list

# List files in the most recent archive
borgmatic list --last 1

# Search for specific files across all archives
borgmatic list --archive nas-01-2025-12-10T12:00:00 | grep "important-file"

# List files matching a pattern
borgmatic list --archive nas-01-2025-12-10T12:00:00 --pattern "*.conf"
```

### Restoring Files

#### Extract to Original Locations

```bash
# Extract entire archive to original locations
borgmatic extract --archive nas-01-2025-12-10T12:00:00

# Extract specific files/directories to original locations
borgmatic extract --archive nas-01-2025-12-10T12:00:00 --path /var/lib/important

# Extract from the most recent archive
borgmatic extract --archive latest
```

#### Extract to Custom Location

```bash
# Extract to a different directory
borgmatic extract --archive nas-01-2025-12-10T12:00:00 --destination /tmp/restore

# Extract specific files to custom location
borgmatic extract --archive nas-01-2025-12-10T12:00:00 \
  --path /var/lib/important/file.db \
  --destination /tmp/restore
```

#### Interactive Restore with Mount

```bash
# Mount an archive as a filesystem (read-only)
mkdir -p /mnt/borg-mount
borgmatic mount --archive nas-01-2025-12-10T12:00:00 --mount-point /mnt/borg-mount

# Now you can browse and copy files
ls -la /mnt/borg-mount/var/lib/
cp /mnt/borg-mount/var/lib/important/file.db /tmp/

# Unmount when done
borgmatic umount --mount-point /mnt/borg-mount
```

### Manually Running Backups

```bash
# Run a backup now (as root, since the service runs as root)
sudo borgmatic create

# Run with verbose output for debugging
sudo borgmatic create -v

# Run only for a specific repository
sudo borgmatic create --repository rsync.net

# Dry run to see what would be backed up (doesn't create archive)
sudo borgmatic create --dry-run -v
```

### Managing Archives

```bash
# Delete a specific archive
borgmatic delete --archive nas-01-2025-12-01T12:00:00

# Apply retention policy without creating new backup (prune old archives)
borgmatic prune

# Compact repository to reclaim space after pruning
borgmatic compact

# View repository statistics
borgmatic info --stats
```

### Troubleshooting

#### Test Configuration

```bash
# Validate your borgmatic configuration
borgmatic config validate

# View the merged configuration
borgmatic config generate
```

#### Debug Issues

```bash
# Run with maximum verbosity
sudo borgmatic create -v 2

# View borgmatic logs
journalctl -u borgmatic -n 100

# Follow borgmatic logs in real-time
journalctl -u borgmatic -f

```

#### Repository Issues

```bash
# Break lock if backup was interrupted
borgmatic break-lock

# Check and repair repository
borgmatic check --repair

# Verify archive consistency
borgmatic check --verify-data
```

### Common Recovery Scenarios

#### Restore a Single File

```bash
# Find which archive has the file
borgmatic list | grep "important.conf"

# Extract just that file
borgmatic extract \
  --archive nas-01-2025-12-10T12:00:00 \
  --path /etc/important.conf \
  --destination /tmp/restore
```

#### Restore an Entire Directory from Yesterday

```bash
# List recent archives
borgmatic list --last 7

# Extract directory from yesterday's backup
borgmatic extract \
  --archive nas-01-2025-12-09T12:00:00 \
  --path /var/lib/myapp \
  --destination /tmp/restore
```

#### Browse Archive Before Restoring

```bash
# Mount the archive
mkdir -p /mnt/borg
borgmatic mount --archive nas-01-2025-12-10T12:00:00 --mount-point /mnt/borg

# Verify contents
ls -la /mnt/borg/var/lib/

# Copy what you need
cp -a /mnt/borg/var/lib/myapp /tmp/restored-myapp

# Unmount
borgmatic umount --mount-point /mnt/borg
```

#### Restore from Specific Point in Time

```bash
# List archives to find the right timestamp
borgmatic list

# Extract from before the problem occurred
borgmatic extract \
  --archive nas-01-2025-12-08T12:00:00 \
  --destination /tmp/restore
```

### Performance Tips

```bash
# Check repository size and deduplicated data
borgmatic info --stats

# View compression statistics for recent archives
borgmatic list --format "{archive}{NL}  Original: {original_size}{NL}  Compressed: {compressed_size}{NL}"

# See which files are largest in an archive
borgmatic list --archive nas-01-2025-12-10T12:00:00 --format "{size:10} {path}{NL}" | sort -rn | head -20
```

### Emergency Recovery (If Config Is Lost)

If you lose your borgmatic config but have the SSH key and passphrase:

```bash
# Set the passphrase environment variable
export BORG_PASSPHRASE=$(cat /var/run/agenix/borg-passphrase)

# Use borg directly to access the repository
borg list --remote-path=borg14 ssh://de4729@de4729.rsync.net/./backups-nas-01

# Extract using borg directly
borg extract --remote-path=borg14 \
  ssh://de4729@de4729.rsync.net/./backups-nas-01::nas-01-2025-12-10T12:00:00
```

**Important Notes:**
- Always run backup/restore operations as root (or the user that runs the service)
- Test your restores regularly to ensure backups are working correctly
- Keep your encryption passphrase and SSH keys in a safe place separate from the server
- When using `--destination` for extracts, the original directory structure is preserved inside the destination

