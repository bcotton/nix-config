# Redis Admin Guide

## Overview

Redis is a general-purpose in-memory data store running on nas-01, available for multiple services to use as a cache, session store, or message broker.

- **Port**: 6379
- **Bind**: 0.0.0.0 (all interfaces)
- **Instance name**: `clubcotton` (NixOS named instance)
- **Service**: `redis-clubcotton.service`
- **Unix socket**: `/run/redis-clubcotton/redis.sock`
- **Storage**: ZFS dataset `ssdpool/local/redis` (NVMe RAIDZ1)
- **Persistence**: RDB snapshots + AOF (append-only file)
- **Max memory**: 4GB (noeviction policy)

## Current Configuration

### NixOS Module

Redis is managed via `services.clubcotton.redis` in `hosts/nixos/nas-01/default.nix`:

```nix
services.clubcotton.redis = {
  bindAddress = "0.0.0.0";
  openFirewall = true;
  maxMemory = "4gb";
  # requirePassFile = config.age.secrets.redis-password.path;
  zfsDataset = {
    name = "ssdpool/local/redis";
    properties = {
      recordsize = "64K";
      mountpoint = "/ssdpool/local/redis";
      compression = "lz4";
      atime = "off";
      quota = "50G";
      "com.sun:auto-snapshot" = "true";
    };
  };
};
```

### Storage Layout

```
/ssdpool/local/redis/           # ZFS dataset (lz4 compressed, 64K recordsize)
  dump.rdb                      # RDB point-in-time snapshot
  appendonly.aof                # Append-only file (every write logged)
```

### Persistence Strategy

Redis uses both persistence modes simultaneously:

- **RDB snapshots**: Automatic point-in-time dumps at intervals:
  - After 900 seconds if at least 1 key changed
  - After 300 seconds if at least 10 keys changed
  - After 60 seconds if at least 10,000 keys changed
- **AOF (Append-Only File)**: Every write operation logged, fsync'd every second
  - AOF auto-rewrites when it doubles in size (minimum 64MB)
  - On restart, Redis replays the AOF to restore state

This combination provides both fast recovery (RDB) and minimal data loss (AOF, ~1 second worst case).

## Service Management

### Check status

```bash
# Service status
systemctl status redis-clubcotton.service

# View logs
journalctl -u redis-clubcotton.service --since "1 hour ago"

# Redis info
redis-cli -p 6379 INFO server
redis-cli -p 6379 INFO memory
redis-cli -p 6379 INFO persistence
```

### Basic operations

```bash
# Ping test
redis-cli -p 6379 PING

# If password is set:
redis-cli -p 6379 -a "$(cat /run/agenix/redis-password)" PING

# Connect via unix socket (no auth needed from localhost)
redis-cli -s /run/redis-clubcotton/redis.sock PING

# Check connected clients
redis-cli -p 6379 CLIENT LIST

# Check memory usage
redis-cli -p 6379 INFO memory
```

### Restart service

```bash
sudo systemctl restart redis-clubcotton.service
journalctl -u redis-clubcotton.service -f
```

## Authentication

### Current State

By default, Redis runs without a password. With `protected-mode = yes`:
- **Localhost connections**: work without authentication
- **LAN connections**: refused by Redis (protected mode blocks non-loopback without a password)

This is safe for initial setup and testing. LAN clients cannot connect until authentication is enabled.

### Enabling Authentication

1. Create the agenix secret:
   ```bash
   cd /path/to/nix-config
   agenix -e redis-password.age
   # Enter a strong password (plain text, no key=value format)
   # Example: xK9$mP2!qR7@nL4
   ```

2. Uncomment the secret declaration in `secrets/default.nix`:
   ```nix
   age.secrets."redis-password" = lib.mkIf config.services.clubcotton.redis.enable {
     file = ./redis-password.age;
     owner = "redis-clubcotton";
     group = "redis-clubcotton";
     mode = "0400";
   };
   ```

3. Uncomment `requirePassFile` in `hosts/nixos/nas-01/default.nix`:
   ```nix
   requirePassFile = config.age.secrets.redis-password.path;
   ```

4. Build and deploy:
   ```bash
   just build nas-01
   just deploy nas-01
   ```

### Client Access With Authentication

Once a password is set, all clients must authenticate:

```bash
# CLI with password
redis-cli -h nas-01 -p 6379 -a "password"

# Or authenticate after connecting
redis-cli -h nas-01 -p 6379
> AUTH password

# Application connection strings
# redis://:password@nas-01:6379/0
```

Services connecting to Redis will need the password configured. Pass it via environment variable or config file, never hardcoded.

## Backup and Recovery

### Backup Strategy

Redis data is protected by three layers:

1. **ZFS snapshots (sanoid)**: 36 hourly, 30 daily, 3 monthly
2. **ZFS replication (syncoid)**: `ssdpool/local/redis` -> `backuppool/local/nas-01/redis`
3. **Redis built-in persistence**: RDB + AOF files survive restarts

ZFS snapshots are atomic, so both RDB and AOF files are captured in a consistent state. No special pre-backup hooks are needed.

### Manual snapshot

```bash
# Trigger a Redis background save
redis-cli -p 6379 BGSAVE

# Check last save time
redis-cli -p 6379 LASTSAVE

# Create a ZFS snapshot
sudo zfs snapshot ssdpool/local/redis@manual-$(date +%Y%m%d-%H%M)
```

### Check backup status

```bash
# List ZFS snapshots
zfs list -t snapshot -r ssdpool/local/redis

# Check syncoid replication status
systemctl status syncoid-redis.service
journalctl -u syncoid-redis.service --since "1 day ago"

# Check backup target
zfs list -t snapshot -r backuppool/local/nas-01/redis
```

### Recovery from ZFS snapshot

```bash
# Stop Redis
sudo systemctl stop redis-clubcotton.service

# List available snapshots
zfs list -t snapshot -r ssdpool/local/redis

# Rollback to a snapshot
sudo zfs rollback ssdpool/local/redis@<snapshot-name>

# Start Redis (it will replay AOF automatically)
sudo systemctl start redis-clubcotton.service
```

### Recovery from backuppool

```bash
# If ssdpool is lost, restore from backuppool
sudo systemctl stop redis-clubcotton.service

# Send from backup to ssdpool
sudo zfs send backuppool/local/nas-01/redis@<snapshot> | sudo zfs receive ssdpool/local/redis

# Start Redis
sudo systemctl start redis-clubcotton.service
```

## Monitoring

### Key metrics to watch

```bash
# Memory usage vs limit
redis-cli -p 6379 INFO memory | grep -E "used_memory_human|maxmemory_human"

# Connected clients
redis-cli -p 6379 INFO clients | grep connected_clients

# Persistence status
redis-cli -p 6379 INFO persistence | grep -E "rdb_last_save_time|aof_enabled|aof_last_rewrite"

# Keyspace (databases with keys)
redis-cli -p 6379 INFO keyspace

# Slow queries
redis-cli -p 6379 SLOWLOG GET 10
```

### ZFS dataset health

```bash
# Dataset usage
zfs list ssdpool/local/redis

# Pool health
zpool status ssdpool
```

## Troubleshooting

### Redis won't start

```bash
# Check logs
journalctl -u redis-clubcotton.service -n 50

# Verify data directory exists and has correct ownership
ls -la /ssdpool/local/redis/
# Should be owned by redis-clubcotton:redis-clubcotton

# Verify ZFS dataset is mounted
zfs get mounted ssdpool/local/redis
```

### AOF corruption after crash

```bash
# Stop Redis
sudo systemctl stop redis-clubcotton.service

# Check and repair AOF
redis-check-aof --fix /ssdpool/local/redis/appendonly.aof

# Start Redis
sudo systemctl start redis-clubcotton.service
```

### Memory limit reached

If `maxmemory-policy` is `noeviction` (default), Redis will return errors on write commands when memory is full:

```bash
# Check current usage
redis-cli -p 6379 INFO memory

# Option 1: Increase maxmemory in NixOS config and redeploy
# Option 2: Manually clear data
redis-cli -p 6379 FLUSHDB        # Clear current database
redis-cli -p 6379 FLUSHALL       # Clear all databases (destructive!)

# Option 3: Change eviction policy temporarily
redis-cli -p 6379 CONFIG SET maxmemory-policy allkeys-lru
```

### Connection refused from LAN

If protected mode is on and no password is set, Redis rejects non-localhost connections:

```
DENIED Redis is running in protected mode...
```

Fix: Enable authentication (see Authentication section above) or connect via localhost/unix socket.

## Connecting Services

To connect a NixOS service to this Redis instance:

```nix
# In your service configuration
services.myservice = {
  redisUrl = "redis://nas-01:6379/0";
  # Or with password:
  # redisUrl = "redis://:${password}@nas-01:6379/0";
};
```

Different databases (0-15) can be used to isolate services:
- Database 0: default / general purpose
- Database 1-15: assign per service as needed

Services on the same host can also connect via the unix socket at `/run/redis-clubcotton/redis.sock` for better performance and no authentication requirement.
