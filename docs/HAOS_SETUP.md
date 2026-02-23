# Home Assistant OS (HAOS) VM Setup

Configuration guide for the HAOS virtual machine running in the Incus cluster, including SSH access to the base OS and multi-VLAN networking.

## Table of Contents

- [Overview](#overview)
- [VM Configuration](#vm-configuration)
- [SSH Access to Base OS](#ssh-access-to-base-os)
- [VLAN Networking](#vlan-networking)
- [Firewall](#firewall)
- [Re-Setup Script](#re-setup-script)
- [HA Container Network Access](#ha-container-network-access)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

## Overview

HAOS runs as an Incus VM managed by the `incus-cluster` module. The VM needs:

1. **SSH access to the base OS** (port 22222) for low-level configuration
2. **VLAN sub-interfaces** so Home Assistant can discover and communicate with devices on all network segments

### Architecture

```
Incus Host (nix-01)
  br0 (VLAN filtering=off, passes all tagged frames)
    └─ tap device (VM port)
         └─ HAOS VM (prod-homeassistant)
              enp5s0 ─── 192.168.5.20/24  (native VLAN 5, DHCP)
              enp5s0.10 ─ 192.168.10.x/24 (VLAN 10, DHCP)
              enp5s0.20 ─ 192.168.20.x/24 (VLAN 20, DHCP)
                │
                ├─ hassio bridge (172.30.32.0/23) ← HA containers
                └─ docker0 bridge (172.30.232.0/23) ← system containers
```

## VM Configuration

The HAOS VM is defined in `data/incus/clubcotton.nix`:

```nix
prod-homeassistant = {
  type = "vm";
  deploy = "opaque";
  profile = "haos";
  imageAlias = "haos";
  storagePool = "local";
  network = {
    mode = "bridged";
    parent = "br0";
    hwaddr = "00:16:3e:3d:95:f2";  # Fixed MAC for DHCP reservation
  };
  extraConfig = {
    "migration.stateful" = "true";
    "boot.autostart" = "true";
  };
};
```

Key details:
- **Profile**: `haos` (4 CPU, 8G RAM, 64G disk, secure boot disabled)
- **Network**: Bridged to `br0` with a fixed MAC address
- **Image**: Imported manually via `terraform/images/haos/run.sh --import`
- **Storage**: `local` pool (node-local ZFS)

## SSH Access to Base OS

HAOS provides SSH access to the underlying OS on **port 22222** (distinct from the SSH add-on which runs on port 22 inside a container). This requires injecting an SSH public key via a virtual USB drive labeled `CONFIG`.

### SSH Key Location

```
~/.ssh/haos_ed25519       # Private key
~/.ssh/haos_ed25519.pub   # Public key
```

### How It Works

Physical HAOS devices use a USB drive labeled `CONFIG` containing an `authorized_keys` file. Since the VM has no physical USB ports, we:

1. Create a FAT-formatted disk image on the Incus host
2. Write the SSH public key as `authorized_keys` inside it
3. Attach it to the VM as a USB disk device (`io.bus=usb`)
4. Reboot the VM so HAOS auto-imports the key on boot
5. Detach the disk image (key persists in HAOS)

### Manual Procedure

```bash
# 1. Generate SSH key (if needed)
ssh-keygen -t ed25519 -f ~/.ssh/haos_ed25519 -N "" -C "haos-access"

# 2. Create FAT disk image on the Incus host
ssh root@nix-01.lan "
  mkdir -p /tmp/haos-config
  dd if=/dev/zero of=/tmp/haos-config.img bs=1M count=32
  mkfs.vfat -n CONFIG /tmp/haos-config.img
"

# 3. Write authorized_keys to the disk image
cat ~/.ssh/haos_ed25519.pub | ssh root@nix-01.lan "
  mount -o loop /tmp/haos-config.img /tmp/haos-config
  cp /dev/stdin /tmp/haos-config/authorized_keys
  sync
  umount /tmp/haos-config
"

# 4. Attach to VM as USB disk and reboot
ssh root@nix-01.lan "
  incus config device add prod-homeassistant config-usb disk \
    source=/tmp/haos-config.img io.bus=usb
  incus restart prod-homeassistant --timeout 120
"

# 5. Wait for boot, then test SSH
sleep 45
ssh -i ~/.ssh/haos_ed25519 -p 22222 root@192.168.5.20 "echo connected"

# 6. Clean up the CONFIG disk (key is now imported)
ssh root@nix-01.lan "
  incus config device remove prod-homeassistant config-usb
  rm -f /tmp/haos-config.img
  rmdir /tmp/haos-config 2>/dev/null
"
```

### Connecting

```bash
ssh -i ~/.ssh/haos_ed25519 -p 22222 root@192.168.5.20
```

Add to `~/.ssh/config` for convenience:

```
Host haos
  HostName 192.168.5.20
  Port 22222
  User root
  IdentityFile ~/.ssh/haos_ed25519
```

## VLAN Networking

### Why No Host-Side Changes Are Needed

The Incus host bridge (`br0`) has **VLAN filtering disabled** (`/sys/class/net/br0/bridge/vlan_filtering = 0`). This means all 802.1Q-tagged frames pass through the bridge to all ports, including the VM's tap device. The host's own VLAN sub-interfaces (`br0.10`, `br0.20`) only extract tagged traffic for the host — they don't filter what reaches the VM.

### Configuring VLANs Inside HAOS

HAOS uses NetworkManager (`nmcli`) for network configuration. VLAN sub-interfaces are created on the VM's primary NIC (`enp5s0`) and persist across reboots.

```bash
# SSH into the HAOS base OS
ssh -i ~/.ssh/haos_ed25519 -p 22222 root@192.168.5.20

# Create VLAN 10 interface (DHCP)
nmcli connection add type vlan con-name enp5s0.10 ifname enp5s0.10 \
  dev enp5s0 id 10 ipv4.method auto ipv6.method disabled

# Create VLAN 20 interface (DHCP)
nmcli connection add type vlan con-name enp5s0.20 ifname enp5s0.20 \
  dev enp5s0 id 20 ipv4.method auto ipv6.method disabled

# Activate them
nmcli connection up enp5s0.10
nmcli connection up enp5s0.20
```

### Persistence

NetworkManager stores connections in `/etc/NetworkManager/system-connections/`:

```
Supervisor enp5s0.nmconnection   # Native VLAN (managed by HAOS)
enp5s0.10.nmconnection           # VLAN 10 (our addition)
enp5s0.20.nmconnection           # VLAN 20 (our addition)
```

These survive HAOS updates and reboots. They do **not** survive a full HAOS image reimport (new VM from scratch).

### Removing VLANs

```bash
nmcli connection delete enp5s0.10
nmcli connection delete enp5s0.20
```

## Firewall

An nftables firewall filters inbound connections to the HAOS VM. HA can reach out to all networks freely; only new incoming connections are filtered.

### Policy

| Network | Interface | Policy |
|---------|-----------|--------|
| Main LAN (192.168.5.0/24) | `enp5s0` | Full trust |
| IoT VLAN (192.168.20.0/24) | `enp5s0.20` | HA integration ports only |
| Guest VLAN (192.168.10.0/24) | `enp5s0.10` | Block all |
| Docker/Supervisor | `hassio`, `docker0`, `veth*` | Full trust |

### IoT VLAN Allowed Ports

| Port | Protocol | Service |
|------|----------|---------|
| 5353 | UDP | mDNS (ESPHome, Chromecast, Shelly) |
| 1900 | UDP | SSDP/UPnP (Hue, WLED) |
| 8123 | TCP | HA API/WebSocket (device webhooks) |
| 1883 | TCP | MQTT (Mosquitto broker) |
| 5683 | UDP | CoAP (Thread/Matter) |
| 21063 | TCP | HomeKit bridge |
| 18555 | TCP | go2rtc (camera streaming) |

### How It Works

The firewall uses a separate nftables table (`inet haos-firewall`) that doesn't interfere with Docker/Supervisor's iptables rules. The `ct state established,related accept` rule ensures all outbound connections from HA get return traffic regardless of source VLAN.

Files on the HAOS VM:
- `/mnt/data/firewall/haos-firewall.nft` — nftables rules (on persistent data partition)
- `/mnt/data/firewall/load.sh` — loader script
- `/etc/udev/rules.d/90-haos-firewall.rules` — loads rules when NIC comes up (on overlay partition)

Source of truth: `scripts/haos-firewall.nft` in this repo.

### Managing the Firewall

```bash
# SSH into HAOS base OS
ssh -i ~/.ssh/haos_ed25519 -p 22222 root@192.168.5.20

# View current rules and drop counters
nft list table inet haos-firewall

# Reload after editing rules
nft -f /mnt/data/firewall/haos-firewall.nft

# Temporarily disable (until next boot)
nft delete table inet haos-firewall

# Add a port (e.g., allow Zigbee coordinator on IoT VLAN)
# Edit /mnt/data/firewall/haos-firewall.nft, then reload
```

### Persistence

- **HAOS updates**: The udev rule (overlay partition) and nft rules (data partition) both survive HAOS updates.
- **HAOS reimport**: A new VM from scratch requires re-running `scripts/haos-setup.sh`, which deploys the firewall rules.
- **Live migration**: Firewall rules live in VM memory (nftables) and persist across migration. The files on disk are part of the VM's virtual disk.

## Re-Setup Script

After reimporting the HAOS image (new VM), run this script to restore SSH access and VLAN configuration. The script is located at `scripts/haos-setup.sh`.

```bash
# From your workstation:
./scripts/haos-setup.sh
```

The script:
1. Generates an SSH key pair if `~/.ssh/haos_ed25519` doesn't exist
2. Creates a CONFIG USB disk image with the public key
3. Attaches it to the HAOS VM and reboots
4. Waits for SSH to become available
5. Creates VLAN 10 and VLAN 20 sub-interfaces
6. Verifies connectivity
7. Cleans up the CONFIG disk

## HA Container Network Access

Home Assistant containers on the `hassio` bridge (172.30.32.0/23) reach VLAN devices automatically via the kernel's routing table and iptables MASQUERADE rules:

```
# HAOS iptables NAT (automatic, managed by Docker/HAOS):
MASQUERADE  all  --  172.30.32.0/23   0.0.0.0/0    # hassio bridge
MASQUERADE  all  --  172.30.232.0/23  0.0.0.0/0    # docker0 bridge
```

When an HA container sends traffic to 192.168.10.x or 192.168.20.x:
1. Kernel routes it to `enp5s0.10` or `enp5s0.20`
2. iptables MASQUERADE rewrites the source IP to the VLAN interface IP
3. The reply comes back to the VLAN IP and is de-NATed to the container

This means HA integrations (ESPHome, Shelly, etc.) can communicate with devices on any VLAN without additional configuration inside HA.

## Verification

### Check VLAN Interfaces

```bash
ssh -i ~/.ssh/haos_ed25519 -p 22222 root@192.168.5.20

# List all network devices
nmcli device status

# Check VLAN IPs
ip -4 addr show enp5s0.10
ip -4 addr show enp5s0.20
```

### Check L2 Reachability

HAOS base OS has no `ping` command. Use the ARP neighbor table instead:

```bash
# Check discovered neighbors on each VLAN
ip neigh show dev enp5s0.10
ip neigh show dev enp5s0.20
```

If you see entries with `REACHABLE` or `STALE` states, VLAN connectivity is working.

### Check From Host

```bash
ssh root@nix-01.lan
ping -c 2 192.168.10.10   # HAOS VLAN 10 IP
ping -c 2 192.168.20.19   # HAOS VLAN 20 IP
```

### Check Routing Inside HAOS

```bash
ip route
# Expected:
# default via 192.168.5.1 dev enp5s0 ... metric 100
# default via 192.168.10.1 dev enp5s0.10 ... metric 402
# default via 192.168.20.1 dev enp5s0.20 ... metric 403
# 192.168.5.0/24 dev enp5s0 ... metric 100
# 192.168.10.0/24 dev enp5s0.10 ... metric 402
# 192.168.20.0/24 dev enp5s0.20 ... metric 403
```

The native VLAN (metric 100) is always preferred for default routing.

## Troubleshooting

### SSH Connection Refused on Port 22222

The SSH key was not imported. Re-run the CONFIG USB injection:

```bash
./scripts/haos-setup.sh
```

Or manually re-inject the key (see [SSH Access to Base OS](#ssh-access-to-base-os)).

### VLANs Not Getting DHCP Addresses

1. **Check 8021q module**: `modprobe 8021q` inside HAOS (should already be loaded)
2. **Check VLAN interfaces exist**: `nmcli device status` should show `enp5s0.10` and `enp5s0.20`
3. **Check DHCP server**: Ensure dnsmasq on dns-01 is serving DHCP on VLANs 10 and 20
4. **Re-activate**: `nmcli connection up enp5s0.10`

### HA Can't Discover Devices on VLANs

1. **Verify HAOS has VLAN IPs**: `ip -4 addr show enp5s0.10`
2. **Check NAT rules**: `iptables -t nat -L -n | grep MASQUERADE`
3. **Check routing**: `ip route` should show routes for 192.168.10.0/24 and 192.168.20.0/24
4. **mDNS**: Some integrations use mDNS which may not cross VLAN boundaries without an mDNS reflector/repeater on the router

### After HAOS Update

HAOS updates preserve NetworkManager connections. VLANs should survive updates automatically. If they disappear, re-run the VLAN setup portion of the script:

```bash
ssh -i ~/.ssh/haos_ed25519 -p 22222 root@192.168.5.20 "
  nmcli connection add type vlan con-name enp5s0.10 ifname enp5s0.10 \
    dev enp5s0 id 10 ipv4.method auto ipv6.method disabled
  nmcli connection add type vlan con-name enp5s0.20 ifname enp5s0.20 \
    dev enp5s0 id 20 ipv4.method auto ipv6.method disabled
  nmcli connection up enp5s0.10
  nmcli connection up enp5s0.20
"
```
