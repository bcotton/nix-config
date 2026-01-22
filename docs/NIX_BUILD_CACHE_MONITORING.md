# Nix Build and Cache Monitoring

## Overview

Automated monitoring of the Nix distributed build infrastructure and binary cache system, integrated with Prometheus and Alertmanager.

## What's Monitored

### Infrastructure Components
- **Binary Cache Accessibility** - Verifies the cache endpoint is reachable
- **Distributed Builds** - Detects if builds are using remote builders (nix-01, nix-02, nix-03)
- **Cache Hit Functionality** - Confirms cache hits work for both local and upstream packages
- **Upstream Cache Proxy** - Tests the nginx proxy to cache.nixos.org

### Metrics Collected

All metrics are exported in Prometheus format via node_exporter textfile collector:

```promql
# Timestamp of last check
nix_build_cache_check_timestamp

# Whether distributed builds are working
# 1 = working, 0 = failed, -1 = not configured
nix_distributed_build_success

# Which builders were used in the test
nix_builder_used{builder="hostname"}

# Whether local cache is serving hits
# 1 = working, 0 = failed
nix_local_cache_hit

# Whether upstream cache proxy is accessible
# 1 = accessible, 0 = not accessible
nix_upstream_cache_accessible

# Whether cache info endpoint is accessible
# 1 = accessible, 0 = not accessible
nix_cache_info_accessible

# Which test package was used (for tracking rotation)
nix_test_package_info{package="packagename"}
```

## Configuration

### Module Location

The monitoring is implemented as a NixOS module:
- **Module**: `modules/prometheus/nix-build-cache-check.nix`
- **Imported by**: `hosts/nixos/nas-01/default.nix`

### Current Configuration (nas-01)

```nix
services.prometheus.nixBuildCacheCheck = {
  enable = true;
  interval = "15m";           # Check every 15 minutes
  cacheUrl = "http://nas-01:80";
};
```

**Note**: Test packages rotate automatically every 15 minutes through: `hello`, `cowsay`, `figlet`, `fortune`, `lolcat`, `sl`. After each test run, the package is deleted from the local store. This ensures every monitoring run actually tests the build/cache infrastructure rather than just finding packages already present.

### Module Options

```nix
services.prometheus.nixBuildCacheCheck = {
  enable = true;              # Enable the monitoring service

  interval = "15m";           # How often to run (systemd timer format)
                              # Examples: "5m", "30m", "1h"
                              # Note: Package rotation is tied to 15min intervals

  cacheUrl = "http://nas-01:80";  # URL of the Nix binary cache

  metricsPath = "/var/lib/prometheus-node-exporter-text-files/nix_build_cache.prom";
                              # Where metrics file is written
};
```

## Alerts Configured

All alerts are defined in `modules/prometheus/prometheus.rules.yaml`:

### Critical Alerts

#### NixCacheNotAccessible
- **Trigger**: `nix_cache_info_accessible == 0` for 5 minutes
- **Severity**: Critical
- **Description**: The binary cache is unreachable

### Warning Alerts

#### NixDistributedBuildsNotWorking
- **Trigger**: `nix_distributed_build_success == 0` for 10 minutes
- **Severity**: Warning
- **Description**: Distributed builds are failing

#### NixCacheNotHitting
- **Trigger**: `nix_local_cache_hit == 0` for 10 minutes
- **Severity**: Warning
- **Description**: Cache is not serving successful hits

#### NixUpstreamCacheProxyDown
- **Trigger**: `nix_upstream_cache_accessible == 0` for 5 minutes
- **Severity**: Warning
- **Description**: nginx proxy to cache.nixos.org is not accessible

#### NixBuildCacheCheckStale
- **Trigger**: Check hasn't run in over 30 minutes
- **Severity**: Warning
- **Description**: Monitoring service may have stopped

## How It Works

### Test Process

The monitoring script rotates through different test packages every 15 minutes to ensure it actually tests the build/cache chain rather than just finding packages already in the local store.

**Package Rotation**: `hello`, `cowsay`, `figlet`, `fortune`, `lolcat`, `sl` (6 packages rotating every 15 minutes = 90 minute full cycle)

**Important**: After testing, the script **deletes the test packages from the local store** using `nix-store --delete`. This ensures every run performs actual builds/cache fetches rather than finding packages already present.

**Build Method**: Uses `nix build nixpkgs#package` (flakes) instead of `nix-build '<nixpkgs>'` to avoid NIX_PATH/channel dependencies.

1. **Cache Accessibility Check**
   - Fetches `http://nas-01:80/nix-cache-info`
   - Verifies the endpoint responds

2. **Distributed Build Test**
   - Builds current test package (selected from rotation) using `nix build`
   - Monitors build logs for remote builder usage
   - Tracks which specific builders (nix-01, nix-02, nix-03) were used
   - Captures store path for cleanup

3. **Cache Hit Test**
   - Builds the same package twice using `nix build`
   - Verifies second build uses cache (local or upstream)
   - Detects if package is already in local store

4. **Upstream Cache Proxy Test**
   - Queries cache endpoint through nginx proxy
   - Verifies proxy is functioning

5. **Cleanup**
   - Deletes test package from local store
   - Ensures next run will test actual build/cache functionality
   - Gracefully handles deletion failures (if package is in use)

### Systemd Integration

Two systemd units are created:

#### Service: nix-build-cache-check.service
- Type: oneshot
- Runs the validation script
- Outputs metrics to `/var/lib/prometheus-node-exporter-text-files/nix_build_cache.prom`

#### Timer: nix-build-cache-check.timer
- Runs 5 minutes after boot
- Repeats every 15 minutes (configurable)
- Persistent: catches up if system was off

### Node Exporter Integration

The module:
1. Creates the textfile directory: `/var/lib/prometheus-node-exporter-text-files`
2. Writes metrics to the directory every 15 minutes

**Note**: The node_exporter textfile collector must be configured elsewhere (it's already configured by `modules/zfs/monitoring.nix` on hosts with ZFS, or can be configured in the host's configuration). The module assumes textfile collector is available and just writes to the standard directory.

## Grafana Dashboard Queries

### Cache Health Overview

```promql
# Current cache status
nix_cache_info_accessible

# Cache hit rate over last hour
avg_over_time(nix_local_cache_hit[1h])
```

### Builder Usage

```promql
# Show which builders are being used
sum by (builder) (nix_builder_used)

# Builder usage over time
increase(nix_builder_used[1h])
```

### Distributed Build Success

```promql
# Success rate over last day
avg_over_time(nix_distributed_build_success[24h])

# Current status (-1=not configured, 0=failed, 1=success)
nix_distributed_build_success
```

### Service Health

```promql
# Time since last check (should be < 900 seconds)
time() - nix_build_cache_check_timestamp

# Alert if check is stale
(time() - nix_build_cache_check_timestamp) > 1800

# Current test package being used
nix_test_package_info
```

## Troubleshooting

### Check Service Status

```bash
# View service status
ssh nas-01 systemctl status nix-build-cache-check.service

# View timer status
ssh nas-01 systemctl status nix-build-cache-check.timer

# View service logs
ssh nas-01 journalctl -u nix-build-cache-check.service -f

# Manually trigger check
ssh nas-01 systemctl start nix-build-cache-check.service
```

### Check Metrics Output

```bash
# View current metrics
ssh nas-01 cat /var/lib/prometheus-node-exporter-text-files/nix_build_cache.prom

# Check if node_exporter is serving them
curl -s http://nas-01:9100/metrics | grep nix_
```

### Verify Prometheus Scraping

```bash
# Check if Prometheus has the metrics
curl -s http://admin:9001/api/v1/query?query=nix_cache_info_accessible

# View in Prometheus UI
# Navigate to: http://admin:9001/graph
# Query: nix_cache_info_accessible
```

### Common Issues

#### Metrics Not Appearing
1. Check service ran successfully: `systemctl status nix-build-cache-check.service`
2. Verify metrics file exists: `ls -la /var/lib/prometheus-node-exporter-text-files/`
3. Check node_exporter is running: `systemctl status prometheus-node-exporter.service`
4. Verify textfile collector is enabled: `curl http://localhost:9100/metrics | grep textfile`
5. Verify Prometheus scrape config includes nas-01

**If textfile collector is not configured**: Add to your host configuration:
```nix
services.prometheus.exporters.node = {
  enabledCollectors = ["textfile"];
  extraFlags = ["--collector.textfile.directory=/var/lib/prometheus-node-exporter-text-files"];
};
```

#### Distributed Build Check Failing
1. Verify builders are configured: `nix show-config | grep builders`
2. Test SSH to builders: `ssh -i /run/agenix/nix-builder-ssh-key nix-builder@nix-01`
3. Check `/etc/nix/machines` file exists

#### Cache Hit Check Failing
1. Test cache manually: `curl http://nas-01:80/nix-cache-info`
2. Check Harmonia is running: `systemctl status harmonia.service`
3. Check nginx proxy: `systemctl status nginx.service`

## Integration with Existing Monitoring

This monitoring integrates with:

1. **Prometheus** (on admin host)
   - Scrapes metrics via node_exporter
   - Evaluates alert rules
   - Stores time-series data

2. **Alertmanager** (on admin host)
   - Receives alerts from Prometheus
   - Routes to configured receivers
   - Manages alert lifecycle

3. **Node Exporter** (on nas-01)
   - Collects textfile metrics
   - Exposes metrics on port 9100
   - Already configured for other metrics (ZFS, SMART, etc.)

## Future Enhancements

Potential improvements:
- Add cache usage statistics (hit rate percentage)
- Monitor build queue length
- Track build duration per builder
- Monitor nginx cache disk usage specifically
- Add builder performance metrics
- Test with larger packages periodically

## Related Documentation

- [BUILD_AND_CACHE.md](./BUILD_AND_CACHE.md) - Complete build and cache infrastructure documentation
- [ZFS_ADMIN_GUIDE.md](./ZFS_ADMIN_GUIDE.md) - ZFS monitoring (similar pattern)
- Prometheus module: `modules/prometheus/`
- Alert rules: `modules/prometheus/prometheus.rules.yaml`

## Deployment

To deploy these changes to nas-01:

```bash
# Build configuration locally
just build nas-01

# Deploy to nas-01
just deploy nas-01

# Or switch on nas-01 directly
ssh nas-01
cd /path/to/nix-config
sudo nixos-rebuild switch --flake .#nas-01
```

After deployment, the monitoring will start automatically:
1. Timer activates 5 minutes after boot
2. First check runs after 5 minutes
3. Subsequent checks every 15 minutes
4. Metrics available immediately via node_exporter
5. Alerts active in Prometheus after first check
