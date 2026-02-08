# ZFS Administration Guide

## Overview

This guide covers the ZFS configuration and management practices for the clubcotton infrastructure, including snapshot management, backup strategies, and best practices for maintaining ZFS pools across multiple hosts.

## Current Infrastructure

### Host Overview

#### nas-01 (Primary Storage Server)
- **Role**: Primary NAS with multiple ZFS pools for different workloads
- **Pools**:
  - `rpool` (864G): Mirrored root pool on 2x 1TB drives (WD Blue SA510 + SPCC SSD)
  - `ssdpool` (14.6T): RAIDZ1 pool on 4x Samsung 990 PRO 4TB NVMe drives
  - `mediapool` (43.6T): RAIDZ1 pool on 3x Seagate drives for media storage
  - `backuppool` (43.6T): RAIDZ1 pool on 3x Seagate drives for backup storage

#### Other ZFS Hosts
- **natalya-01**: Single-disk ZFS root (`rpool`) - Media player system
- **condo-01**: Single-disk ZFS root (`rpool`) - Remote location system  
- **nix-04**: Single-disk ZFS root (`rpool`) - Development/testing system

### Pool Configuration Details

#### nas-01 Pool Specifications

**rpool (Root Pool)**
- **Configuration**: Mirror (2 drives)
- **Capacity**: 864G total
- **Usage**: System root, /var/lib, /var/log, /nix, /home
- **Drives**: 
  - WD Blue SA510 2.5" 1TB SSD
  - SPCC Solid State Disk 1TB
- **Features**: Standard root filesystem layout with reserved space

**ssdpool (High-Performance Storage)**
- **Configuration**: RAIDZ1 (4 drives)
- **Capacity**: 14.6T total
- **Usage**: Database storage, Incus containers
- **Drives**: 4x Samsung SSD 990 PRO 4TB NVMe
- **Mount Points**:
  - `/db` - PostgreSQL databases
  - Incus container storage

**mediapool (Media Storage)**
- **Configuration**: RAIDZ1 (3 drives)  
- **Capacity**: 43.6T total
- **Usage**: Media files, documents, user data
- **Drives**: 3x Seagate drives (various models)
- **Mount Points**:
  - `/media/books`, `/media/documents`, `/media/movies`
  - `/media/music`, `/media/photos`, `/media/shows`
  - `/media/tomcotton/*`, `/media/webdav`, `/media/youtube`

**backuppool (Backup Storage)**
- **Configuration**: RAIDZ1 (3 drives)
- **Capacity**: 43.6T total  
- **Usage**: Backup destination for syncoid replication
- **Drives**: 3x Seagate drives (various models)
- **Contains**: Replicated snapshots from all other pools

## Snapshot Management with Sanoid

### Sanoid Configuration

Sanoid is configured with two snapshot templates:

#### Backup Template (Critical Data)
```
[template_backup]
autoprune=true
autosnap=true
daily=30      # Keep 30 daily snapshots
hourly=36     # Keep 36 hourly snapshots (1.5 days)
monthly=3     # Keep 3 monthly snapshots
```

**Applied to**:
- `rpool/local/lib` (system state)
- `rpool/safe/home` (user home directories)
- `ssdpool/local/database` (PostgreSQL databases)

#### Media Template (Less Critical Data)
```
[template_media]  
autoprune=true
autosnap=true
daily=30      # Keep 30 daily snapshots
hourly=0      # No hourly snapshots (reduces overhead)
monthly=6     # Keep 6 monthly snapshots
```

**Applied to**:
- `mediapool/local/documents`
- `mediapool/local/photos` 
- `mediapool/local/tomcotton/audio-library`
- `mediapool/local/tomcotton/data`

### Snapshot Naming Convention

Sanoid creates snapshots with descriptive names:
- `autosnap_YYYY-MM-DD_HH:MM:SS_frequency`
- Examples:
  - `autosnap_2025-02-23_14:00:05_hourly`
  - `autosnap_2025-02-23_00:00:04_daily`
  - `autosnap_2025-02-17_01:00:06_monthly`

## Backup Strategy with Syncoid

### Syncoid Configuration

Syncoid replicates snapshots from source datasets to the backup pool on nas-01:

#### Replication Jobs
```nix
commands = {
  var_lib = {
    source = "rpool/local/lib";
    target = "backuppool/local/nas-01/var-lib";
  };
  database = {
    source = "ssdpool/local/database";
    target = "backuppool/local/nas-01/database";
  };
  photos = {
    source = "mediapool/local/photos";
    target = "backuppool/local/nas-01/photos";
  };
  documents = {
    source = "mediapool/local/documents";
    target = "backuppool/local/nas-01/documents";
  };
  tomcotton_data = {
    source = "mediapool/local/tomcotton/data";
    target = "backuppool/local/nas-01/tomcotton-data";
  };
  tomcotton_audio_library = {
    source = "mediapool/local/tomcotton/audio-library";
    target = "backuppool/local/nas-01/tomcotton-audio-library";
  };
};
```

### Backup Schedule

All sanoid and syncoid jobs run hourly at the top of the hour.

**Execution Order**:
1. Sanoid creates snapshots on source datasets
2. Syncoid replicates new snapshots to backup destinations
3. Old snapshots are pruned according to retention policies

## ZFS Best Practices

### Pool Management

#### Pool Health Monitoring
```bash
# Check pool status
zpool status

# Check pool I/O statistics  
zpool iostat -v

# Check for errors
zpool status -x

# View pool properties
zpool get all <poolname>
```

#### Important Pool Properties
- **ashift=12**: Optimized for 4K sector drives (all pools configured correctly)
- **autotrim=on**: Automatic TRIM for SSDs (enabled on all pools)
- **compression=lz4**: Efficient compression (enabled by default)

### Dataset Management

#### Declarative Management with disko-zfs

Datasets on nas-01 are managed declaratively via [disko-zfs](https://github.com/numtide/disko-zfs) in `hosts/nixos/nas-01/default.nix`. This means dataset creation and property enforcement happen automatically at system activation time.

**How it works**:
- disko-zfs auto-detects all disko-defined pools (rpool, ssdpool, mediapool, backuppool)
- At activation, it creates any missing datasets and enforces declared properties
- Changes are previewed via `nixos-rebuild dry-activate` before applying

**Critical safety warnings**:

1. **disko-zfs WILL DESTROY undeclared datasets.** Every dataset in a disko-managed pool must be listed in the `disko.zfs.settings.datasets` config. If you create a dataset manually with `zfs create`, you must immediately add it to the config or it will be destroyed on next activation.

2. **disko-zfs WILL UNSET undeclared properties.** Any locally-set property (mountpoint, reservation, quota, com.sun:auto-snapshot, etc.) not declared in the config will be `zfs inherit`'d on next activation, reverting to the parent's value. For example, an undeclared `mountpoint` on `mediapool/local/photos` would revert from `/media/photos` to `none`.

**Adding a new dataset**:
```nix
# In hosts/nixos/nas-01/default.nix, inside disko.zfs.settings.datasets:
"mediapool/local/new-service" = {
  properties = {
    mountpoint = "/media/new-service";
    compression = "lz4";
    "com.sun:auto-snapshot" = "true";
  };
};
```

Then:
```bash
# Preview changes (ALWAYS do this first)
sudo nixos-rebuild dry-activate --flake '.#nas-01'

# Verify the output shows:
#   - "zfs create mediapool/local/new-service" in Additive Commands
#   - NO unexpected entries in Destructive Commands or zfs inherit lines

# Apply
sudo nixos-rebuild switch --flake '.#nas-01'
```

**Auditing current state vs config**:
```bash
# Show all locally-set properties (these must all be in the config)
zfs get -s local -o name,property,value all ssdpool mediapool backuppool | grep -v '@'

# Show all datasets (these must all be listed in the config)
zfs list -t filesystem -o name -H -r ssdpool mediapool backuppool
```

#### Key Dataset Properties
```bash
# View dataset properties
zfs get all <dataset>

# Important properties to monitor:
zfs get compression,recordsize,atime,mountpoint <dataset>
```

**Optimized Settings**:
- **compression=lz4**: Good balance of speed and space savings
- **recordsize=64K**: Default, good for general use
- **recordsize=1M**: Used for media files (movies, music, shows)
- **recordsize=8K**: Used for databases
- **atime=off**: Reduces write overhead

### Snapshot Management

#### Manual Snapshot Operations
```bash
# Create manual snapshot
zfs snapshot <dataset>@<name>

# List snapshots
zfs list -t snapshot

# Destroy snapshot
zfs destroy <dataset>@<snapshot>

# Rollback to snapshot (DESTRUCTIVE)
zfs rollback <dataset>@<snapshot>
```

#### Snapshot Space Usage
```bash
# Check snapshot space usage
zfs list -o space

# Check specific dataset snapshot usage
zfs list -t snapshot <dataset>
```

### Backup and Recovery

#### Local Backup Verification
```bash
# Verify syncoid replication status
systemctl status syncoid-*

# Check backup pool contents
zfs list backuppool/local/nas-01

# Compare source and backup snapshots
zfs list -t snapshot <source_dataset>
zfs list -t snapshot <backup_dataset>
```

#### Recovery Procedures

**Dataset Recovery from Backup**:
```bash
# Send backup to new location
zfs send backuppool/local/nas-01/<dataset>@<snapshot> | \
  zfs receive <new_location>

# Incremental recovery
zfs send -i <old_snapshot> <new_snapshot> <source> | \
  zfs receive <destination>
```

**File-Level Recovery**:
```bash
# Mount snapshot for file recovery
zfs mount <dataset>@<snapshot>

# Access files in .zfs/snapshot directory
ls <mountpoint>/.zfs/snapshot/<snapshot_name>/
```

## Offsite Backup Strategy

### Current Limitations
The current setup provides excellent local redundancy and snapshot-based recovery, but lacks offsite backup capabilities. 

### Recommended Offsite Strategy

#### Option 1: ZFS Send/Receive to Remote Location
```bash
# Send encrypted incremental backups to remote ZFS system
zfs send -w -i <last_sent> <dataset>@<latest> | \
  ssh <remote_host> zfs receive <remote_dataset>
```

**Benefits**:
- Native ZFS efficiency with incremental sends
- Encryption in transit and at rest
- Snapshot preservation

**Requirements**:
- Remote ZFS-capable system
- Reliable network connection
- SSH key authentication

#### Option 2: Cloud Storage Integration
```bash
# Use zfs-backup-s3 or similar tools
zfs send <dataset>@<snapshot> | \
  gzip | \
  aws s3 cp - s3://backup-bucket/<dataset>-<snapshot>.gz
```

**Benefits**:
- Leverages cloud storage durability
- Geographic distribution
- Cost-effective for long-term retention

**Considerations**:
- Network bandwidth requirements
- Cloud storage costs
- Encryption and security

#### Option 3: Hybrid Approach
1. **Local replication**: Continue current syncoid setup for fast recovery
2. **Weekly offsite**: Send weekly snapshots to remote location
3. **Monthly archive**: Long-term cloud storage for disaster recovery

### Implementation Recommendations

1. **Immediate**: Set up remote ZFS system at different location
2. **Configure**: Automated weekly sends of critical datasets
3. **Monitor**: Implement alerting for backup failures
4. **Test**: Regular recovery drills to verify backup integrity

## Monitoring and Alerting

### Key Metrics to Monitor

#### Pool Health
- Pool status (ONLINE/DEGRADED/FAULTED)
- Disk errors (read/write/checksum)
- Pool capacity utilization
- Scrub status and results

#### Snapshot Health
- Sanoid service status
- Syncoid replication success/failure
- Snapshot creation frequency
- Backup pool space utilization

### Recommended Monitoring Setup

```bash
# Check pool health
zpool status -x

# Monitor service status
systemctl status sanoid syncoid-*

# Check disk space
zfs list -o space

# Review recent logs
journalctl -u sanoid -u syncoid-* --since "1 day ago"
```

### Alerting Triggers
- Pool degradation or disk failures
- Snapshot creation failures
- Backup replication failures  
- Pool capacity > 80%
- Scrub errors or completion

## Maintenance Procedures

### Regular Maintenance Tasks

#### Weekly
- Review pool status and error counts
- Check snapshot creation and retention
- Verify backup replication success
- Monitor pool capacity trends

#### Monthly  
- Initiate pool scrubs during low-usage periods
- Review and clean up old snapshots if needed
- Test file recovery procedures
- Update ZFS pool features if available

#### Quarterly
- Test disaster recovery procedures
- Review and update backup retention policies
- Evaluate pool expansion needs
- Update documentation

### Pool Scrubbing
```bash
# Start scrub (I/O intensive, schedule during low usage)
zpool scrub <poolname>

# Check scrub status
zpool status <poolname>

# Cancel scrub if needed
zpool scrub -s <poolname>
```

### Pool Expansion
```bash
# Add new disk to existing pool (RAIDZ expansion requires ZFS 2.2+)
zpool add <poolname> <new_disk>

# Replace disk in pool
zpool replace <poolname> <old_disk> <new_disk>

# Check resilver progress
zpool status <poolname>
```

## Troubleshooting

### Common Issues

#### Syncoid Permission Errors
**Symptom**: "cannot destroy snapshots: permission denied"
**Solution**: 
```bash
# Grant necessary permissions to syncoid user
zfs allow syncoid snapshot,mount,destroy <dataset>
```

#### Pool Feature Warnings
**Symptom**: "Some supported and requested features are not enabled"
**Solution**:
```bash
# Upgrade pool features (ensure compatibility first)
zpool upgrade <poolname>

# Check available features
zpool upgrade -v
```

#### High Memory Usage
**Symptom**: ZFS consuming excessive RAM
**Solution**:
```bash
# Check ARC usage
cat /proc/spl/kstat/zfs/arcstats

# Adjust ARC size if needed (in /etc/modprobe.d/zfs.conf)
options zfs zfs_arc_max=<bytes>
```

### Emergency Procedures

#### Pool Import Issues
```bash
# Force import pool
zpool import -f <poolname>

# Import pool with different name
zpool import <poolname> <new_name>

# Import read-only for recovery
zpool import -o readonly=on <poolname>
```

#### Dataset Recovery
```bash
# Check for available snapshots
zfs list -t snapshot <dataset>

# Rollback to last good snapshot
zfs rollback <dataset>@<snapshot>

# Clone snapshot for investigation
zfs clone <dataset>@<snapshot> <dataset>_recovery
```

### SMART Monitoring and Disk Health Management

#### Critical SMART Attributes to Monitor

**Reallocated Sector Count (`Reallocated_Sector_Ct`)**
- **What it means**: Number of bad sectors that have been remapped to spare sectors
- **Why critical**: Strong predictor of imminent drive failure
- **Action thresholds**:
  - `1-5 sectors`: Monitor closely, plan replacement within 3-6 months
  - `>5 sectors`: Plan immediate replacement (weeks, not months)
  - `>50 sectors`: Replace immediately - high failure risk

**Current Pending Sector (`Current_Pending_Sector`) - MOST URGENT**
- **What it means**: Sectors with read errors waiting for reallocation attempt
- **Why critical**: Data may be unreadable RIGHT NOW, active instability
- **Immediate danger**: ZFS pool errors, data corruption, cascading failures
- **Actions**: IMMEDIATE - Force reallocation via SMART test or ZFS scrub

**Offline Uncorrectable (`Offline_Uncorrectable`)**
- **What it means**: Sectors that couldn't be read during offline scan
- **Why critical**: Indicates potential data loss
- **Actions**: Immediate replacement required

#### SMART Monitoring Commands

```bash
# Check overall SMART health
smartctl -H /dev/sdX

# View all SMART attributes
smartctl -A /dev/sdX

# Run short self-test (2 minutes)
smartctl -t short /dev/sdX

# Run extended self-test (hours)
smartctl -t long /dev/sdX

# Check test results
smartctl -l selftest /dev/sdX

# View error log
smartctl -l error /dev/sdX
```

#### Emergency Pending Sector Response

**When you receive a pending sector alert:**

1. **Immediate Assessment** (within 1 hour):
```bash
# Use the automated disk health check script (recommended)
check-zfs-disk-health

# Or manual check for specific drive
smartctl -A /dev/sdX | grep -E "(Current_Pending_Sector|Reallocated_Sector_Ct|Offline_Uncorrectable)"

# Check ZFS pool status for any errors
zpool status -v

# Check recent ZFS events
zpool events | tail -20
```

2. **Force Reallocation Attempt** (within 4 hours):
```bash
# Method 1: ZFS scrub (safest for active pools)
zfs scrub <affected_pool>

# Method 2: Extended SMART test
smartctl -t long /dev/sdX

# Method 3: Targeted read test (if you can identify affected areas)
dd if=/dev/sdX of=/dev/null bs=4096 count=1000000 skip=<sector_number>
```

3. **Monitor Results** (after 24 hours):
```bash
# Check if pending sectors were successfully reallocated
smartctl -A /dev/sdX | grep -E "(Current_Pending_Sector|Reallocated_Sector_Ct)"

# Possible outcomes:
# GOOD: Pending=0, Reallocated increased (successful reallocation)
# BAD: Pending unchanged, Uncorrectable increased (failed reallocation)
# UGLY: Pending increased (more sectors becoming unstable)
```

4. **Decision Matrix**:
- **Pending sectors cleared**: Monitor closely, plan replacement within 3 months
- **Pending sectors persist >24h**: Replace drive immediately (reallocation failing)
- **Uncorrectable sectors appeared**: Replace drive immediately (data loss risk)
- **More pending sectors appeared**: Replace drive immediately (cascading failure)

#### Why Pending Sectors Are More Dangerous Than Reallocated

| Scenario | Pending Sectors | Reallocated Sectors |
|----------|----------------|-------------------|
| **Data Status** | **May be unreadable** | Successfully moved to spare area |
| **ZFS Impact** | **Pool errors possible** | No immediate impact |
| **Urgency** | **Hours to days** | Weeks to months |
| **Risk Level** | **High - active failure** | Medium - stable condition |
| **Action Required** | **Immediate intervention** | Monitoring and planning |

**Key Point**: Pending sectors represent **active, ongoing failure** while reallocated sectors represent **completed, successful recovery**. Always treat pending sectors as urgent.

#### Automated Disk Health Check Script

A comprehensive disk health check script is automatically installed on all ZFS hosts:

```bash
# Basic health check with drive-to-pool mapping
check-zfs-disk-health

# Verbose output showing all SMART attributes
check-zfs-disk-health --verbose

# JSON output for automation/scripting
check-zfs-disk-health --json
```

**Script Features**:
- **Drive-to-pool mapping**: Shows which ZFS pool each drive belongs to
- **Severity assessment**: Categorizes issues as OK/WARNING/CRITICAL
- **Actionable recommendations**: Tells you exactly which pool to scrub
- **SMART attribute analysis**: Checks all critical attributes automatically
- **Color-coded output**: Easy visual identification of issues
- **JSON support**: For integration with monitoring systems

**Example Output**:
```
=== ZFS Disk Health Check ===

[WARNING] ata-WD_Blue_SA510_2.5_1000GB_24293W800136
  Pool: rpool (ONLINE)
  Serial: WD-WX12345678
  SMART Health: PASSED
  Reallocated Sectors: 3
  Pending Sectors: 0
  Action: MONITOR: Plan replacement within 3-6 months

[CRITICAL] wwn-0x5000c500cbac2c8c
  Pool: mediapool (ONLINE)
  Serial: ZA123456
  SMART Health: PASSED
  Reallocated Sectors: 0
  Pending Sectors: 2
  Action: URGENT: Run 'zfs scrub mediapool' within 4 hours

✅ All other drives healthy!

Pool Status Summary:
  rpool: ONLINE (12% full)
  ssdpool: ONLINE (1% full)
  mediapool: ONLINE (67% full)
  backuppool: ONLINE (14% full)
```

#### Disk Replacement Procedure for ZFS

**For RAIDZ pools (current setup)**:
```bash
# 1. Identify failing disk in pool
zpool status <poolname>

# 2. Take disk offline (if not already failed)
zpool offline <poolname> <failing_disk>

# 3. Physically replace disk

# 4. Replace in ZFS pool
zpool replace <poolname> <old_disk_id> <new_disk_id>

# 5. Monitor resilver progress
zpool status <poolname>

# 6. Verify pool health after resilver
zpool scrub <poolname>
```

**For Mirror pools (rpool)**:
```bash
# 1. Detach failing disk
zpool detach <poolname> <failing_disk>

# 2. Replace disk physically

# 3. Attach new disk to mirror
zpool attach <poolname> <remaining_disk> <new_disk>

# 4. Monitor resilver
zpool status <poolname>
```

#### Proactive Disk Health Management

**Monthly Tasks**:
- Review SMART attribute trends
- Run extended SMART tests on all drives
- Check for any new reallocated sectors
- Monitor drive temperatures

**Quarterly Tasks**:
- Analyze SMART logs for patterns
- Update disk replacement timeline based on health trends
- Test disk replacement procedures in lab environment

**Annual Tasks**:
- Replace drives approaching manufacturer warranty expiration
- Evaluate drive failure patterns for procurement decisions
- Update monitoring thresholds based on experience

#### Drive Replacement Planning Matrix

| SMART Condition | Action Timeline | Risk Level |
|----------------|----------------|------------|
| All attributes normal | Monitor quarterly | Low |
| 1-5 reallocated sectors | Plan replacement 3-6 months | Medium |
| >5 reallocated sectors | Replace within 4 weeks | High |
| Pending sectors present | Run tests, replace if persistent | Medium-High |
| Uncorrectable sectors | Replace immediately | Critical |
| SMART health = FAIL | Replace immediately | Critical |
| Temperature >65°C sustained | Improve cooling, monitor | Medium |
| Temperature >70°C | Replace immediately | Critical |

#### Cost-Benefit Analysis for Replacement

**Replacement Costs** (per drive):
- Consumer drives (4TB): $80-120
- NAS drives (4TB): $120-180  
- Enterprise drives (4TB): $200-300

**Failure Costs**:
- Pool degradation during resilver: Performance impact
- Data recovery services: $500-2000+ per drive
- Downtime costs: Service interruption
- Multiple drive failure: Potential total data loss

**Recommendation**: Replace drives proactively when SMART indicates degradation. The cost of a $150 drive is minimal compared to potential data loss or recovery costs.

## Security Considerations

### Access Control
- ZFS datasets inherit permissions from mount points
- Use ZFS delegation for service accounts (sanoid, syncoid)
- Implement proper SSH key management for remote replication

### Encryption
- Consider ZFS native encryption for sensitive datasets
- Encrypt backups in transit and at rest
- Implement key management procedures

### Network Security
- Use SSH for remote replication
- Implement firewall rules for ZFS-related traffic
- Consider VPN for offsite backup connections

## Performance Optimization

### Pool Layout Optimization
- **RAIDZ1**: Good balance of capacity and redundancy (current setup)
- **RAIDZ2**: Better redundancy for larger arrays
- **Mirror**: Maximum performance, 50% capacity efficiency

### Dataset Tuning
- **recordsize**: Match to workload (64K general, 1M media, 8K database)
- **compression**: lz4 for good balance, lz4hc for better compression
- **atime**: Disable for performance (already configured)

### Memory Tuning
- **ARC size**: Default is 50% of RAM, adjust based on workload
- **L2ARC**: Consider SSD cache for frequently accessed data

## Conclusion

The current ZFS infrastructure provides robust local storage with automated snapshots and replication. The main areas for improvement are:

1. **Offsite backup implementation** for disaster recovery
2. **Enhanced monitoring and alerting** for proactive maintenance
3. **Documentation of recovery procedures** and regular testing

This setup provides excellent protection against hardware failures and user errors through snapshots, with local replication providing additional redundancy. The modular NixOS configuration makes it easy to replicate this setup across multiple hosts while maintaining consistency.

## TODO: Monitoring and Infrastructure Improvements

Based on the audit of the current Prometheus ZFS monitoring configuration, the following improvements are recommended:

### Current ZFS Monitoring Status

**Existing Configuration**:
- ✅ ZFS exporter automatically enabled on all ZFS hosts via `modules/zfs/default.nix`
- ✅ Basic ZFS alerting rules implemented in `prometheus.rules.yaml`:
  - Pool degradation alerts (`zfs_pool_health > 0`)
  - Pool capacity warnings (80% and 90% thresholds)
  - Pool fragmentation alerts (>50% fragmentation ratio)
  - Pool leak detection alerts
- ✅ ZFS exporter included in monitored exporters list (`modules/prometheus/lib.nix`)
- ✅ 30-second scrape interval configured for ZFS metrics

### Priority 1: Critical Monitoring Gaps

#### 1. Sanoid/Syncoid Service Monitoring
**Issue**: No monitoring of snapshot creation and backup replication services
**Impact**: Backup failures could go unnoticed for extended periods

**Implementation**:
```yaml
# Add to prometheus.rules.yaml
- alert: SanoidServiceFailed
  expr: systemd_unit_state{name="sanoid.service",state="failed"} == 1
  for: 5m
  labels:
    severity: critical
  annotations:
    description: 'Sanoid snapshot service failed on {{ $labels.instance }}'

- alert: SyncoidReplicationFailed  
  expr: systemd_unit_state{name=~"syncoid-.*\\.service",state="failed"} == 1
  for: 5m
  labels:
    severity: critical
  annotations:
    description: 'Syncoid replication {{ $labels.name }} failed on {{ $labels.instance }}'

- alert: SanoidSnapshotAge
  expr: (time() - zfs_snapshot_creation_time) > 7200  # 2 hours
  for: 10m
  labels:
    severity: warning
  annotations:
    description: 'No recent snapshots for {{ $labels.dataset }} on {{ $labels.instance }}'
```

#### 2. Disk Health Monitoring
**Issue**: No SMART monitoring for underlying ZFS pool disks
**Impact**: Disk failures may not be detected before pool degradation

**Implementation**:
```nix
# Add to prometheus exporters
services.prometheus.exporters.smartctl = {
  enable = true;
  devices = [
    "/dev/disk/by-id/ata-WD_Blue_SA510_2.5_1000GB_24293W800136"
    "/dev/disk/by-id/ata-SPCC_Solid_State_Disk_AAAA0000000000006990"
    # Add all other disks from nas-01 configuration
  ];
};
```

#### 3. ZFS Scrub Monitoring
**Issue**: No alerts for overdue or failed scrubs
**Impact**: Data integrity issues may go undetected

**Implementation**:
```yaml
- alert: ZfsScrubOverdue
  expr: (time() - zfs_pool_last_scrub_timestamp) > 2592000  # 30 days
  for: 1h
  labels:
    severity: warning
  annotations:
    description: 'ZFS pool {{ $labels.pool }} on {{ $labels.instance }} has not been scrubbed in over 30 days'

- alert: ZfsScrubErrors
  expr: zfs_pool_scrub_errors > 0
  for: 5m
  labels:
    severity: critical
  annotations:
    description: 'ZFS scrub found {{ $value }} errors in pool {{ $labels.pool }} on {{ $labels.instance }}'
```

### Priority 2: Enhanced Monitoring

#### 4. Dataset-Level Monitoring
**Issue**: Current monitoring only covers pool-level metrics
**Enhancement**: Add dataset-specific alerts for quota usage and growth rates

**Implementation**:
```yaml
- alert: ZfsDatasetQuotaExceeded
  expr: zfs_dataset_used_bytes / zfs_dataset_quota_bytes > 0.9
  for: 10m
  labels:
    severity: warning
  annotations:
    description: 'ZFS dataset {{ $labels.dataset }} is at {{ printf "%.1f" $value }}% of quota'

- alert: ZfsDatasetRapidGrowth
  expr: rate(zfs_dataset_used_bytes[1h]) > 1073741824  # 1GB/hour
  for: 30m
  labels:
    severity: warning
  annotations:
    description: 'ZFS dataset {{ $labels.dataset }} growing rapidly at {{ printf "%.2f" $value }} bytes/hour'
```

#### 5. ARC (Adaptive Replacement Cache) Monitoring
**Issue**: No monitoring of ZFS memory usage and cache efficiency
**Enhancement**: Monitor ARC hit ratios and memory pressure

**Implementation**:
```yaml
- alert: ZfsArcLowHitRatio
  expr: zfs_arc_hit_ratio < 0.8
  for: 15m
  labels:
    severity: warning
  annotations:
    description: 'ZFS ARC hit ratio is low ({{ printf "%.2f" $value }}) on {{ $labels.instance }}'

- alert: ZfsArcMemoryPressure
  expr: zfs_arc_size_bytes / zfs_arc_max_bytes > 0.95
  for: 10m
  labels:
    severity: warning
  annotations:
    description: 'ZFS ARC memory usage is high ({{ printf "%.1f" $value }}%) on {{ $labels.instance }}'
```

### Priority 3: Operational Improvements

#### 6. Backup Verification Monitoring
**Issue**: No verification that backup snapshots are actually restorable
**Enhancement**: Implement periodic backup integrity checks

**Tasks**:
- Create automated backup verification scripts
- Monitor backup verification job success/failure
- Alert on backup corruption or inconsistencies

#### 7. Capacity Planning Metrics
**Issue**: Limited trending data for capacity planning
**Enhancement**: Add recording rules for capacity trend analysis

**Implementation**:
```yaml
# Recording rules for capacity planning
groups:
  - name: zfs_capacity_trends
    interval: 300s  # 5 minutes
    rules:
      - record: zfs:pool_capacity_percent
        expr: (zfs_pool_allocated_bytes / (zfs_pool_allocated_bytes + zfs_pool_free_bytes)) * 100
      
      - record: zfs:pool_growth_rate_daily
        expr: rate(zfs_pool_allocated_bytes[24h])
      
      - record: zfs:pool_days_until_full
        expr: zfs_pool_free_bytes / rate(zfs_pool_allocated_bytes[7d])
```

#### 8. Performance Monitoring
**Issue**: No monitoring of ZFS I/O performance metrics
**Enhancement**: Track IOPS, latency, and throughput

**Implementation**:
- Monitor `zpool iostat` metrics via custom exporter
- Alert on high I/O wait times or unusual patterns
- Track read/write error rates per vdev

### Priority 4: Infrastructure Enhancements

#### 9. Offsite Backup Implementation
**Status**: Critical gap in disaster recovery capability
**Timeline**: Immediate priority

**Current Storage Requirements Analysis**:

Based on current syncoid replication jobs, the following datasets require offsite backup:

| Dataset | Current Size | Compression Ratio | Snapshot Count | Growth Pattern |
|---------|-------------|------------------|----------------|----------------|
| `rpool/local/lib` | 34.0G | 1.79x | 71 snapshots | System state (moderate growth) |
| `ssdpool/local/database` | 10.1G | 1.19x | 71 snapshots | Database (steady growth) |
| `mediapool/local/photos` | 561G | 1.00x | 37 snapshots | Photos (high growth) |
| `mediapool/local/documents` | 31.4G | 1.03x | 37 snapshots | Documents (low growth) |
| `mediapool/local/tomcotton/data` | 93.2G | 1.12x | 37 snapshots | User data (moderate growth) |
| `mediapool/local/tomcotton/audio-library` | 542G | 1.04x | 37 snapshots | Audio (stable) |
| **Total Current Data** | **~1.27TB** | | **290 snapshots** | |

**Offsite Storage Calculations**:

**Option 1: Full Replication (Complete Disaster Recovery)**
- **Initial full send**: ~1.27TB (compressed data)
- **Snapshot overhead**: ~5-10% additional (based on current local snapshots)
- **Monthly growth estimate**: ~50-100GB (based on photos/documents growth)
- **Total Year 1**: ~1.4TB initial + ~0.8TB growth = **~2.2TB**

**Option 2: Selective Critical Data Only**
- Exclude media files (photos, audio-library): ~1.1TB reduction
- **Critical data only**: ~170GB (system + database + documents + user data)
- **Total Year 1**: ~200GB initial + ~200GB growth = **~400GB**

**Option 3: Tiered Backup Strategy**
- **Tier 1 (Daily)**: Critical data only (~170GB)
- **Tier 2 (Weekly)**: Full dataset (~1.27TB) 
- **Tier 3 (Monthly)**: Long-term archive with compression

**Cloud Storage Cost Estimates**:

**AWS S3 (Standard)**:
- Full replication: ~$29/month (2.2TB × $0.023/GB × 0.55 retrieval factor)
- Critical only: ~$5/month (400GB × $0.023/GB × 0.55)

**AWS S3 Glacier Deep Archive**:
- Full replication: ~$2.20/month (2.2TB × $0.00099/GB)
- Critical only: ~$0.40/month (400GB × $0.00099/GB)

**rsync.net ZFS-native**:
- Full replication: ~$44/month (2.2TB × $0.02/GB)
- Critical only: ~$8/month (400GB × $0.02/GB)
- **Advantages**: Native ZFS support, incremental sends, snapshot preservation

**Backblaze B2**:
- Full replication: ~$11/month (2.2TB × $0.005/GB)
- Critical only: ~$2/month (400GB × $0.005/GB)

**Recommended Implementation Strategy**:

1. **Phase 1**: Start with critical data only to rsync.net (~$8/month)
   - Immediate protection for irreplaceable system state and databases
   - Native ZFS incremental sends preserve snapshot history
   - Test recovery procedures with smaller dataset

2. **Phase 2**: Add media files with tiered approach
   - Weekly full sends to cheaper storage (Backblaze B2 or S3 Glacier)
   - Keep recent snapshots on rsync.net for fast recovery
   - Archive older snapshots to deep storage

3. **Phase 3**: Implement geographic distribution
   - Primary offsite: rsync.net (fast recovery)
   - Secondary archive: AWS Glacier Deep Archive (long-term retention)

**Implementation Commands**:

```bash
# Initial full send to rsync.net (example)
zfs send -w rpool/local/lib@latest | \
  ssh rsync.net zfs receive backup/nas-01/rpool-local-lib

# Incremental sends (automated)
zfs send -w -i @previous @latest rpool/local/lib | \
  ssh rsync.net zfs receive backup/nas-01/rpool-local-lib
```

**Options**:
1. **Remote ZFS replication** to rsync.net (recommended for critical data)
2. **Cloud backup integration** with encrypted ZFS sends to S3/B2
3. **Hybrid approach** with local + multiple cloud tiers

#### 10. Automated Recovery Testing
**Issue**: No regular testing of recovery procedures
**Enhancement**: Implement automated recovery drills

**Tasks**:
- Monthly automated snapshot restore tests
- Quarterly full pool recovery simulations
- Document and test all recovery procedures

#### 11. Configuration Management ✅ IMPLEMENTED
**Issue**: Manual configuration changes risk inconsistency
**Solution**: disko-zfs module integrated (2026-02-08)

**What was done**:
- Added `disko-zfs` flake input with disko/nixpkgs/flake-parts follows
- NixOS module wired into all hosts via `externalNixOSModules` in `flake-modules/hosts.nix`
- All nas-01 datasets declared in `hosts/nixos/nas-01/default.nix` with full property definitions
- Properties match live state exactly (mountpoint, recordsize, quota, reservation, com.sun:auto-snapshot, etc.)

**Remaining**:
- Extend to other ZFS hosts (natalya-01, condo-01, nix-04) as needed
- Automate pool feature upgrades

### Implementation Timeline

**Week 1-2**: Priority 1 items (service monitoring, disk health, scrub monitoring)
**Week 3-4**: Priority 2 items (dataset monitoring, ARC monitoring)  
**Month 2**: Priority 3 items (backup verification, capacity planning)
**Month 3**: Priority 4 items (offsite backup, recovery testing)

### Monitoring Dashboard Requirements

Create Grafana dashboards for:
1. **ZFS Pool Overview**: Health, capacity, performance per pool
2. **Backup Status**: Sanoid/Syncoid job status and snapshot trends
3. **Disk Health**: SMART metrics and predictive failure indicators
4. **Capacity Planning**: Growth trends and projected full dates
5. **Performance Metrics**: I/O patterns, latency, and cache efficiency

### Testing and Validation

Before implementing monitoring changes:
1. Test all alert rules in staging environment
2. Validate metric collection and retention
3. Verify alert routing and notification delivery
4. Document runbook procedures for each alert type

## Offsite Backup Storage Analysis

### Current Dataset Overview

The following analysis is based on the current syncoid replication jobs and actual dataset sizes as of December 2024:

| Dataset | Current Size | Compression Ratio | Snapshot Count | Data Type | Growth Pattern |
|---------|-------------|------------------|----------------|-----------|----------------|
| `rpool/local/lib` | 34.0G | 1.79x | 71 snapshots | System state | Moderate growth |
| `ssdpool/local/database` | 10.1G | 1.19x | 71 snapshots | PostgreSQL DBs | Steady growth |
| `mediapool/local/photos` | 561G | 1.00x | 37 snapshots | Photo library | High growth |
| `mediapool/local/documents` | 31.4G | 1.03x | 37 snapshots | Documents | Low growth |
| `mediapool/local/tomcotton/data` | 93.2G | 1.12x | 37 snapshots | User data | Moderate growth |
| `mediapool/local/tomcotton/audio-library` | 542G | 1.04x | 37 snapshots | Music library | Stable |
| **Total Current Data** | **1.27TB** | **Avg 1.20x** | **290 snapshots** | | |

### Storage Requirements by Backup Strategy

#### Strategy 1: Full Replication (Complete Disaster Recovery)
**Scope**: All datasets with full snapshot history
- **Initial storage needed**: 1.27TB (current compressed data)
- **Snapshot overhead**: ~127GB (10% based on current local usage)
- **Year 1 projection**: 1.4TB initial + 0.8TB growth = **2.2TB**
- **Year 2 projection**: **3.0TB** (with continued growth)

**Use case**: Complete disaster recovery capability, fastest restore times

#### Strategy 2: Critical Data Only (Essential Systems)
**Scope**: System state, databases, documents, user data (excludes media)
- **Datasets included**: `rpool/local/lib`, `ssdpool/local/database`, `mediapool/local/documents`, `mediapool/local/tomcotton/data`
- **Current size**: 169GB
- **Year 1 projection**: 200GB initial + 200GB growth = **400GB**
- **Year 2 projection**: **600GB**

**Use case**: Protect irreplaceable data, faster/cheaper to implement

#### Strategy 3: Tiered Approach (Recommended)
**Tier 1 (Daily)**: Critical data only - 169GB → 400GB Year 1
**Tier 2 (Weekly)**: Media files - 1.1TB → 1.8TB Year 1  
**Tier 3 (Monthly)**: Compressed archives for long-term retention

**Use case**: Balance of protection, cost, and recovery speed

### Cloud Storage Provider Comparison

#### AWS S3 Pricing (US East)
| Storage Class | $/GB/Month | 2.2TB Cost | 400GB Cost | Retrieval Cost | Use Case |
|---------------|------------|------------|------------|----------------|----------|
| **Standard** | $0.023 | $51/month | $9/month | $0.0004/GB | Frequent access |
| **Standard-IA** | $0.0125 | $28/month | $5/month | $0.01/GB | Monthly access |
| **Glacier Instant** | $0.004 | $9/month | $1.60/month | $0.03/GB | Quarterly access |
| **Glacier Flexible** | $0.0036 | $8/month | $1.44/month | $0.01/GB + time | Archive |
| **Glacier Deep** | $0.00099 | $2.20/month | $0.40/month | $0.02/GB + time | Long-term archive |

#### Alternative Providers
| Provider | $/GB/Month | 2.2TB Cost | 400GB Cost | Features | Notes |
|----------|------------|------------|------------|----------|-------|
| **rsync.net** | $0.02 | $44/month | $8/month | Native ZFS, SSH access | Premium ZFS support |
| **Backblaze B2** | $0.005 | $11/month | $2/month | S3-compatible API | Good value |
| **Wasabi** | $0.0059 | $13/month | $2.36/month | No egress fees | Flat rate pricing |
| **Google Cloud** | $0.02 | $44/month | $8/month | Nearline/Coldline options | Enterprise features |

### Cost Analysis by Implementation Strategy

#### Recommended: Tiered Hybrid Approach

**Phase 1: Critical Data Protection** (Immediate - Month 1)
- **Provider**: rsync.net (native ZFS support)
- **Data**: 169GB → 400GB Year 1
- **Cost**: $8/month → $16/month Year 1
- **Benefits**: Native incremental sends, fast recovery, SSH access

**Phase 2: Media Backup** (Month 2-3)
- **Provider**: Backblaze B2 or AWS S3 Glacier
- **Data**: 1.1TB → 1.8TB Year 1  
- **Cost**: $5.50/month → $9/month Year 1 (B2)
- **Benefits**: Cost-effective bulk storage

**Phase 3: Long-term Archive** (Month 6)
- **Provider**: AWS Glacier Deep Archive
- **Data**: Monthly snapshots, compressed
- **Cost**: $2-3/month
- **Benefits**: Cheapest long-term retention

**Total Monthly Cost**: 
- **Year 1**: $15-25/month (depending on growth)
- **Year 2**: $20-35/month
- **Year 3**: $25-45/month

#### Budget Option: Critical Data Only
- **Provider**: Backblaze B2
- **Data**: 400GB Year 1
- **Cost**: $2/month Year 1
- **Trade-off**: No media protection, but covers all irreplaceable data

#### Premium Option: Full rsync.net
- **Provider**: rsync.net for everything
- **Data**: 2.2TB Year 1
- **Cost**: $44/month Year 1
- **Benefits**: Native ZFS everywhere, consistent tooling, premium support

### Bandwidth Considerations

#### Initial Seed Upload
- **Full dataset**: 1.27TB initial upload
- **Estimated time**: 
  - 100 Mbps: ~30 hours
  - 50 Mbps: ~60 hours
  - 25 Mbps: ~120 hours (5 days)

#### Ongoing Incremental Updates
- **Daily changes**: Estimated 1-5GB/day average
- **Weekly media additions**: 10-20GB typical
- **Bandwidth impact**: Minimal with ZFS incremental sends

### Implementation Recommendations

#### Start Small, Scale Up
1. **Week 1**: Implement critical data backup to rsync.net ($8/month)
2. **Month 2**: Add media files to Backblaze B2 ($5-10/month additional)  
3. **Month 6**: Implement long-term archival to AWS Glacier ($2-3/month additional)

#### Key Decision Factors
- **Budget**: $2/month (critical only) to $50/month (premium full protection)
- **Recovery Speed**: rsync.net fastest, Glacier slowest
- **ZFS Integration**: rsync.net native, others require custom tooling
- **Reliability**: All providers offer 99.9%+ uptime SLAs

#### ROI Analysis
**Cost of data loss**: Irreplaceable photos, documents, system configurations
**Insurance value**: $15-25/month for comprehensive protection
**Comparison**: Less than most streaming service subscriptions
**Peace of mind**: Priceless for 15+ years of digital life
