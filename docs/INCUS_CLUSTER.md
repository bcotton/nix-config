# Incus Cluster Administration

## Cluster Overview

4-node Incus cluster with ZFS storage:

| Node   | CPU                        | Storage          | IP             |
|--------|----------------------------|------------------|----------------|
| nix-01 | Ryzen 7 7840HS (16 threads)| 899 GiB SSD pool | 192.168.5.210  |
| nix-02 | Ryzen 7 7840HS (16 threads)| 899 GiB SSD pool | 192.168.5.212  |
| nix-03 | Ryzen 7 7840HS (16 threads)| 899 GiB SSD pool | 192.168.5.214  |
| nas-01 | EPYC 7402 (48 threads)     | 984 GiB zvol     | 192.168.5.42   |

- nix-01/02/03: Dedicated NVMe SSDs with standalone ZFS `incus` pool
- nas-01: 1TB zvol on `ssdpool` (`ssdpool/local/incus`) with ZFS `incus` pool inside

## Live VM Migration

Live (hot) migration requires two cluster-level configs to handle the heterogeneous CPU hardware:

### 1. CPU baseline

The cluster group pins all VMs to `EPYC-Rome` (Zen 2), the lowest common denominator:

```bash
incus cluster group show default | grep baseline
# instances.vm.cpu.x86_64.baseline: EPYC-Rome
```

Without this, Incus uses `-cpu host,migratable=no` which prevents migration between different CPU models.

To set (already configured):
```bash
incus cluster group set default instances.vm.cpu.x86_64.baseline EPYC-Rome
```

### 2. Consistent maxcpus

Incus sets QEMU's `maxcpus` based on the **host's** physical thread count (16 on Ryzen, 48 on EPYC). This causes `ICH9LPC` device state migration failures because the device state format differs between maxcpus values.

The default profile overrides this to `16` (the minimum across the cluster):

```bash
incus profile show default | grep -A3 raw.qemu
# raw.qemu.conf: |-
#   [smp-opts]
#   cpus = "1"
#   maxcpus = "16"
```

VMs inherit this from the default profile. The `cpus` value is overridden by `limits.cpu` if set on the instance. The `maxcpus = "16"` cap ensures consistent QEMU device state across all nodes.

To set (already configured):
```bash
incus profile set default raw.qemu.conf '[smp-opts]
cpus = "1"
maxcpus = "16"'
```

**Important:** If a new node is added with fewer than 16 threads, `maxcpus` must be lowered across the cluster. Existing VMs would need to be stopped and restarted to pick up the change.

### Container migration

Containers use cold migration (stop/move/start) because CRIU live migration fails on nested UTS namespaces. This is a known CRIU limitation.

## Storage

### nix-01/02/03: Dedicated SSD pools

Each host has a dedicated NVMe SSD (ex-Ceph) with a ZFS pool named `incus`:

```bash
# Provisioned by: scripts/provision-incus-ssd.sh
# Auto-imported at boot via: boot.zfs.extraPools = ["incus"]
```

### nas-01: zvol-backed pool

nas-01 uses a zvol because `disko-zfs` manages `ssdpool` datasets and would destroy undeclared Incus datasets. The zvol provides isolation:

```
ssdpool/local/incus (1TB zvol)
  └── ZFS pool "incus" created inside the zvol
      └── Incus manages datasets freely here
```

```bash
# Provisioned by: scripts/join-incus-nas01.sh
# NixOS config declares the zvol size in clubcotton.zfs_raidz1.ssdpool.volumes
```

## Common Operations

```bash
# Cluster status
incus cluster list

# Storage per-node
incus storage info local --target nix-01

# Launch VM with migration support
incus launch images:ubuntu/24.04 my-vm --vm \
  -c migration.stateful=true \
  -c limits.cpu=4 \
  -c limits.memory=4GiB

# Hot migrate a running VM
incus move my-vm --target nix-02

# Cold migrate a container
incus stop my-container
incus move my-container --target nas-01
incus start my-container
```

## Provisioning Scripts

| Script | Purpose |
|--------|---------|
| `scripts/provision-incus-ssd.sh` | Migrate nix-01/02/03 Incus storage to dedicated SSDs |
| `scripts/join-incus-nas01.sh` | Join nas-01 to the cluster with zvol-backed storage |
