# Garage S3 Admin Guide

## Overview

Garage is a self-hosted S3-compatible object storage service running on nas-01. It provides an S3 API for applications that need object storage (backups, media, application data).

- **S3 API**: `http://nas-01:3900`
- **RPC (inter-node)**: `http://nas-01:3901`
- **Version**: 1.3.0
- **Replication**: Single node (factor=1)
- **Storage**: ZFS dataset `ssdpool/local/garage` (NVMe RAIDZ1)

## Current Configuration

### NixOS Module

Garage is managed via `services.clubcotton.garage` in `hosts/nixos/nas-01/default.nix`:

```nix
services.clubcotton.garage = {
  dataDir = "/ssdpool/local/garage/data";
  metadataDir = "/ssdpool/local/garage/meta";
  rpcSecretFile = config.age.secrets."garage-rpc-secret".path;
  s3ApiBindAddr = "0.0.0.0:3900";
  rpcBindAddr = "0.0.0.0:3901";
  replicationFactor = 1;
  zfsDataset = {
    name = "ssdpool/local/garage";
    properties = {
      mountpoint = "/ssdpool/local/garage";
      compression = "lz4";
      atime = "off";
    };
  };
};
```

### Storage Layout

```
/ssdpool/local/garage/          # ZFS dataset (lz4 compressed, atime=off)
  data/                         # Object data storage
  meta/                         # LMDB metadata database
    db.lmdb/                    # Metadata DB
    cluster_layout              # Cluster layout state
    node_key                    # Node identity keypair
    node_key.pub
    peer_list                   # Known peers
```

### Secrets

- **RPC secret**: `secrets/garage-rpc-secret.age` - 64 hex character shared secret for cluster communication
  - Generate: `openssl rand -hex 32`
  - Edit: `agenix -e garage-rpc-secret.age`

### Cluster Layout

Single node deployment:

```
ID: 85197349c573daee
Zone: dc1
Capacity: 1000 GB
Layout version: 1
```

## CLI Reference

All commands require the config file path:

```bash
garage -c /etc/garage/garage.toml <command>
```

Or as root/sudo (the GARAGE_CONFIG_FILE env var is set for the service user):

```bash
sudo -u garage garage <command>
```

### Node Management

```bash
# Check node status and cluster health
garage status

# Show current cluster layout
garage layout show
```

### Bucket Management

```bash
# Create a bucket
garage bucket create <bucket-name>

# List all buckets
garage bucket list

# Show bucket details (size, objects, keys)
garage bucket info <bucket-name>

# Delete a bucket (must be empty)
garage bucket delete --yes <bucket-name>

# Set a website configuration on a bucket
garage bucket website --allow <bucket-name>
```

### Key Management

```bash
# Create a new API key
garage key create <key-name>

# List all keys
garage key list

# Show key details (access key ID and secret)
garage key info <key-name>

# Delete a key
garage key delete --yes <key-name>

# Rename a key
garage key rename <key-id> <new-name>
```

### Bucket Permissions

```bash
# Grant read/write access to a bucket
garage bucket allow <bucket-name> --read --write --key <key-name>

# Grant read-only access
garage bucket allow <bucket-name> --read --key <key-name>

# Revoke access
garage bucket deny <bucket-name> --read --write --key <key-name>
```

### Aliases

Buckets can have global or local (per-key) aliases:

```bash
# Add a global alias (accessible by bucket name in S3 API)
garage bucket alias <bucket-id> <alias-name>

# Remove a global alias
garage bucket unalias <bucket-id> <alias-name>
```

## Client Configuration

### AWS CLI

```bash
aws configure --profile garage
# Access Key ID: <from garage key info>
# Secret Access Key: <from garage key info>
# Region: garage
# Output format: json
```

Usage:

```bash
# List buckets
aws --endpoint-url http://nas-01:3900 --profile garage s3 ls

# List objects in a bucket
aws --endpoint-url http://nas-01:3900 --profile garage s3 ls s3://bucket-name/

# Upload a file
aws --endpoint-url http://nas-01:3900 --profile garage s3 cp file.txt s3://bucket-name/

# Download a file
aws --endpoint-url http://nas-01:3900 --profile garage s3 cp s3://bucket-name/file.txt .

# Sync a directory
aws --endpoint-url http://nas-01:3900 --profile garage s3 sync ./local-dir s3://bucket-name/prefix/
```

### rclone

```ini
[garage]
type = s3
provider = Other
endpoint = http://nas-01:3900
access_key_id = <access-key>
secret_access_key = <secret-key>
region = garage
```

### s3cmd

```ini
[default]
host_base = nas-01:3900
host_bucket = nas-01:3900/%(bucket)
access_key = <access-key>
secret_key = <secret-key>
use_https = False
```

## Backup Strategy

### What to Back Up

1. **Metadata directory** (`/ssdpool/local/garage/meta`) - Critical. Contains the LMDB database, cluster layout, and node keys. Small but essential for recovery.
2. **Data directory** (`/ssdpool/local/garage/data`) - The actual object data. Size grows with usage.
3. **RPC secret** - Stored in agenix (`secrets/garage-rpc-secret.age`), backed up with the git repo.

### ZFS Snapshots

The garage dataset sits on `ssdpool` which supports ZFS snapshots. To add Garage to the sanoid snapshot schedule, add to `hosts/nixos/nas-01/default.nix`:

```nix
services.sanoid.datasets."ssdpool/local/garage" = {
  useTemplate = ["backup"];
};
```

### Manual Backup

```bash
# Snapshot the dataset
zfs snapshot ssdpool/local/garage@backup-$(date +%Y%m%d)

# Send to backup pool
zfs send ssdpool/local/garage@backup-20260208 | zfs receive backuppool/backup/garage

# Or use garage's built-in export (per-bucket)
aws --endpoint-url http://nas-01:3900 --profile garage \
  s3 sync s3://bucket-name/ /path/to/backup/bucket-name/
```

### Recovery

1. Restore the ZFS dataset from snapshot
2. Ensure the RPC secret matches (`agenix -e garage-rpc-secret.age`)
3. Restart the service: `systemctl restart garage`
4. Verify: `garage status` and `garage bucket list`

## Monitoring

### Current Status

Check service health:

```bash
systemctl status garage
journalctl -u garage -f
garage status
garage stats
```

### Prometheus Metrics

Garage exposes native Prometheus metrics via the admin API on port 3903.

**Endpoints:**
- **Metrics**: `http://nas-01:3903/metrics` (Bearer token required)
- **Health**: `http://nas-01:3903/health` (no auth needed)

**NixOS Configuration:**

```nix
services.clubcotton.garage = {
  # ... existing config ...
  adminApiBindAddr = "0.0.0.0:3903";
  metricsTokenFile = config.age.secrets."garage-metrics-token".path;
};
```

**Secrets:**

The metrics bearer token must be created and kept in sync between Garage and Prometheus:

```bash
# Create/edit the metrics token (same value used by both Garage and Prometheus)
agenix -e garage-metrics-token.age
# Content: a random hex string, e.g., output of: openssl rand -hex 32
```

**Key Metrics:**
- `garage_build_info` - Build version information
- `garage_local_disk_avail{volume=data|metadata}` - Available disk space
- `garage_local_disk_total{volume=data|metadata}` - Total disk space
- `cluster_healthy`, `cluster_available` - Cluster health status (0 or 1)
- `api_s3_request_counter{api_endpoint}` - S3 API request counts
- `api_s3_error_counter{api_endpoint,status_code}` - S3 API error counts
- `block_resync_queue_length` - Block resync queue depth
- `block_resync_errored_blocks` - Blocks that failed to resync (should be 0)

**Testing manually:**

```bash
# With bearer token authentication:
curl -H "Authorization: Bearer $(cat /run/agenix/garage-metrics-token)" http://localhost:3903/metrics

# Quick health check (no auth):
curl http://localhost:3903/health
```

### Grafana Dashboard

A Garage dashboard ("Garage S3 Object Storage") is provisioned in Grafana showing:
- Cluster health status (healthy, available, connected nodes)
- Disk usage gauges for data and metadata volumes
- S3 request/error rates and p95 latency by endpoint
- Block manager I/O, resync queue, and errored blocks
- RPC request rates, errors, and timeouts

### Alerts

The following Prometheus alerts are configured:

| Alert | Severity | Description |
|-------|----------|-------------|
| GarageDown | critical | Admin API unreachable for 5 minutes |
| GarageClusterUnhealthy | critical | Cluster reports unhealthy |
| GarageClusterUnavailable | critical | Cluster unavailable for operations |
| GarageDiskSpaceLow | warning | Data volume < 20% free |
| GarageDiskSpaceCritical | critical | Data volume < 10% free |
| GarageMetadataDiskSpaceLow | warning | Metadata volume < 20% free |
| GarageHighS3ErrorRate | warning | Sustained S3 errors > 1/sec |
| GarageBlockResyncErrors | warning | Errored blocks in resync |
| GarageBlockResyncQueueHigh | warning | Resync queue > 1000 blocks |

## Troubleshooting

### Service won't start

```bash
# Check logs
journalctl -u garage -e

# Verify config file is valid
cat /etc/garage/garage.toml

# Check directory permissions
ls -la /ssdpool/local/garage/
ls -la /ssdpool/local/garage/data/
ls -la /ssdpool/local/garage/meta/
```

### "not_configured" in logs

The cluster layout hasn't been applied yet. See the initial setup steps:

```bash
garage status
garage layout assign -z dc1 -c 1T <NODE_ID>
garage layout apply --version <next-version>
```

### Reset cluster layout

```bash
# Revert unapplied changes
garage layout revert --version <current-version>

# Or re-assign and apply with next version number
garage layout assign -z dc1 -c 1T <NODE_ID>
garage layout apply --version <next-version>
```

### "Could not save peer list" warning

Check that the metadata directory exists and is writable by the garage user:

```bash
ls -la /ssdpool/local/garage/meta/
# Should be owned by garage:garage
```

## Multi-Node Expansion

To expand to multiple nodes in the future:

1. Set `replicationFactor = 3` (requires at least 3 nodes)
2. Share the same RPC secret across all nodes
3. Configure `rpcPublicAddr` on each node
4. Connect nodes: `garage node connect <node-id>@<ip>:3901`
5. Assign roles: `garage layout assign -z <zone> -c <capacity> <node-id>`
6. Apply: `garage layout apply --version <next>`

Changing `replicationFactor` on an existing cluster requires deleting `cluster_layout` files on all nodes and rebalancing. See the [Garage documentation](https://garagehq.deuxfleurs.fr/documentation/reference-manual/configuration/) for details.
