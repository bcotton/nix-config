# Networking Architecture

This document describes the networking architecture for the homelab infrastructure, including VLAN segmentation, NIC bonding, and bridge networking for virtualization.

## Table of Contents

- [Overview](#overview)
- [Network Topology](#network-topology)
- [VLAN Configuration](#vlan-configuration)
- [Host Configurations](#host-configurations)
- [systemd-networkd Module](#systemd-networkd-module)
- [Switch Configuration](#switch-configuration)
- [Incus VM Networking](#incus-vm-networking)
- [Adding New Hosts](#adding-new-hosts)
- [Troubleshooting](#troubleshooting)

## Overview

The homelab network uses VLAN segmentation to separate different types of traffic and services. All compute hosts (nix-01/02/03, nas-01) have access to multiple VLANs through systemd-networkd configuration.

### Key Features

- **VLAN Segmentation**: Traffic segregated across VLANs 5, 10, and 20
- **NIC Bonding**: Dual-NIC hosts use 802.3ad (LACP) for bandwidth aggregation and redundancy
- **Bridge Networking**: Incus VMs attach to host bridges for full network access
- **systemd-networkd**: Modern, declarative network configuration
- **Consistent Configuration**: Single NixOS module manages all network topologies

## Network Topology

### VLAN Layout

```
VLAN 5 (Native)     - 192.168.5.0/24   - Primary management/services network
VLAN 10            - 192.168.10.0/24  - Secondary network segment
VLAN 20            - 192.168.20.0/24  - Tertiary network segment
```

### Infrastructure Components

- **Gateway**: 192.168.5.1
- **DNS Server**: dns-01 (192.168.5.220)
- **Compute Hosts**:
  - nas-01: 192.168.5.300 (single NIC)
  - nix-01: 192.168.5.210 (dual NIC bonded)
  - nix-02: 192.168.5.212 (dual NIC bonded)
  - nix-03: 192.168.5.214 (dual NIC bonded)

## VLAN Configuration

### VLAN 5 (Native/Untagged)

- **Subnet**: 192.168.5.0/24
- **Gateway**: 192.168.5.1
- **DNS**: 192.168.5.220
- **Purpose**: Primary network for management and most services
- **Configuration**: Static IP assignment on hosts

### VLAN 10 & 20

- **Subnets**: 192.168.10.0/24, 192.168.20.0/24
- **Configuration**: DHCP from dnsmasq
- **Purpose**: Segmented networks for specific services/containers
- **Route Metric**: 1024 (higher than native VLAN)
  - Ensures VLAN 5 remains the primary network path
  - VLANs 10 and 20 are reachable but don't override default routing

## Host Configurations

### Dual-NIC Bonded Hosts (nix-01/02/03)

These hosts run Incus and need bridge networking for VM access to VLANs.

**Network Stack**:
```
Physical NICs (enp2s0, enp3s0)
    ↓
802.3ad LACP Bond (bond0)
    ↓
Bridge (br0) ← Incus VMs attach here
    ↓
├── Native VLAN 5: br0 (static IP)
├── VLAN 10: br0.10 (DHCP)
└── VLAN 20: br0.20 (DHCP)
```

**NixOS Configuration Example** (nix-01):
```nix
clubcotton.systemd-network = {
  enable = true;
  mode = "bonded";
  interfaces = [ "enp2s0" "enp3s0" ];
  bondName = "bond0";
  bridgeName = "br0";
  enableIncusBridge = true;
  enableVlans = true;
  nativeVlan = {
    id = 5;
    address = "192.168.5.210/24";
    gateway = "192.168.5.1";
    dns = [ "192.168.5.220" ];
  };
};
```

**Benefits**:
- **Bandwidth Aggregation**: Combined throughput of both NICs
- **Redundancy**: Automatic failover if one NIC fails
- **VM Network Access**: VMs see all VLANs through bridge

### Single-NIC Host (nas-01)

nas-01 has a single NIC but still needs access to all VLANs for services.

**Network Stack**:
```
Physical NIC (enp0s31f6)
    ↓
├── Native VLAN 5: enp0s31f6 (static IP)
├── VLAN 10: enp0s31f6.10 (DHCP)
└── VLAN 20: enp0s31f6.20 (DHCP)
```

**NixOS Configuration**:
```nix
clubcotton.systemd-network = {
  enable = true;
  mode = "single-nic";
  interfaces = [ "enp0s31f6" ];
  enableIncusBridge = false;
  enableVlans = true;
  nativeVlan = {
    id = 5;
    address = "192.168.5.300/24";
    gateway = "192.168.5.1";
    dns = [ "192.168.5.220" ];
  };
};
```

**Benefits**:
- **Simple Configuration**: No bonding complexity
- **Multi-VLAN Access**: All VLANs reachable for services
- **Resource Efficient**: No bridge overhead when not running VMs

### DNS Server (dns-01)

dns-01 uses traditional NixOS networking (not systemd-networkd) as it predates the unified module.

**Configuration** (hosts/nixos/dns-01/default.nix):
```nix
networking = {
  hostName = "dns-01";
  defaultGateway = "192.168.5.1";
  nameservers = ["192.168.5.220"];
  interfaces.eno1.ipv4.addresses = [{
    address = "192.168.5.220";
    prefixLength = 24;
  }];
  vlans = {
    vlan10 = { id = 10; interface = "eno1"; };
    vlan20 = { id = 20; interface = "eno1"; };
  };
  interfaces.vlan10.ipv4.addresses = [{
    address = "192.168.10.220";
    prefixLength = 24;
  }];
  interfaces.vlan20.ipv4.addresses = [{
    address = "192.168.20.220";
    prefixLength = 24;
  }];
};
```

**Migration Note**: dns-01 can be migrated to systemd-networkd module in the future if desired.

## systemd-networkd Module

The networking configuration is managed by a custom NixOS module at `modules/systemd-network/`.

### Module Architecture

The module provides:
- **Dual-mode operation**: Single-NIC or bonded dual-NIC
- **VLAN support**: Automatic creation of VLAN interfaces
- **Bridge integration**: Optional bridge for VM networking
- **Declarative configuration**: All settings in NixOS configuration

### Configuration Modes

1. **`mode = "single-nic"`**
   - For hosts with one network interface
   - VLANs created directly on interface
   - Optional bridge support

2. **`mode = "bonded"`**
   - For hosts with two network interfaces
   - Creates 802.3ad LACP bond
   - VLANs created on bond or bridge
   - Requires switch LACP configuration

### Key Options

See `modules/systemd-network/README.md` for complete option documentation.

Common options:
- `enable`: Enable systemd-networkd configuration
- `mode`: "single-nic" or "bonded"
- `interfaces`: List of physical interface names
- `enableIncusBridge`: Create bridge for VM networking
- `enableVlans`: Enable VLAN 10 and 20 interfaces
- `nativeVlan`: Static IP configuration for native VLAN

## Switch Configuration

### LACP Requirements

For bonded hosts (nix-01/02/03), the network switch must support and have LACP enabled.

**Required Switch Configuration**:
- **Protocol**: 802.3ad (LACP)
- **Mode**: Active or Passive LACP
- **Link Aggregation Group**: Both ports for each host in same LAG
- **VLAN Trunking**: Allow VLANs 5, 10, 20 on LAG

**Example Switch Configuration** (varies by vendor):
```
# Cisco/IOS example
interface Port-channel1
 description nix-01-bond
 switchport mode trunk
 switchport trunk allowed vlan 5,10,20

interface GigabitEthernet1/0/1
 description nix-01-enp2s0
 channel-group 1 mode active

interface GigabitEthernet1/0/2
 description nix-01-enp3s0
 channel-group 1 mode active
```

### VLAN Configuration

All switch ports connected to compute hosts should be configured as trunk ports with:
- **Native VLAN**: 5 (untagged)
- **Tagged VLANs**: 10, 20

## Incus VM Networking

### Host Configuration

Hosts running Incus (nix-01/02/03) have `enableIncusBridge = true`, which:
- Creates a bridge device (br0)
- Attaches bond to bridge
- Creates VLAN interfaces on bridge
- Allows VMs to attach to bridge

### VM Network Access

VMs attached to the bridge can access all VLANs:

**Option 1: Single VLAN per VM**
```bash
# Create VM with network on native VLAN
incus launch ubuntu:22.04 myvm --network br0
# VM gets IP on VLAN 5 via DHCP
```

**Option 2: Multi-VLAN VM**

Inside the VM, configure VLAN interfaces:
```bash
# Native VLAN (untagged)
ip addr add 192.168.5.100/24 dev eth0
ip route add default via 192.168.5.1

# VLAN 10
ip link add link eth0 name eth0.10 type vlan id 10
ip addr add 192.168.10.100/24 dev eth0.10
ip link set eth0.10 up

# VLAN 20
ip link add link eth0 name eth0.20 type vlan id 20
ip addr add 192.168.20.100/24 dev eth0.20
ip link set eth0.20 up
```

**Option 3: systemd-networkd in VM**

Create `/etc/systemd/network/10-eth0.10.netdev`:
```ini
[NetDev]
Name=eth0.10
Kind=vlan

[VLAN]
Id=10
```

Create `/etc/systemd/network/20-eth0.10.network`:
```ini
[Match]
Name=eth0.10

[Network]
DHCP=yes
```

Repeat for VLAN 20.

### Incus Profile for Multi-VLAN

```bash
incus profile create multi-vlan
incus profile device add multi-vlan eth0 nic \
  nictype=bridged \
  parent=br0
```

## Adding New Hosts

### With Dual NICs (for Incus/VM hosts)

1. **Identify NIC names**: Run `ip link` to find interface names

2. **Add to host configuration**:
```nix
# hosts/nixos/new-host/default.nix
{
  imports = [
    ./hardware-configuration.nix
    ../../../modules/systemd-network
  ];

  networking = {
    hostName = "new-host";
    hostId = "XXXXXXXX";  # Generate with: head -c4 /dev/urandom | od -A none -t x4
  };

  clubcotton.systemd-network = {
    enable = true;
    mode = "bonded";
    interfaces = [ "enp1s0" "enp2s0" ];  # Your NIC names
    bondName = "bond0";
    bridgeName = "br0";
    enableIncusBridge = true;
    enableVlans = true;
    nativeVlan = {
      id = 5;
      address = "192.168.5.XXX/24";  # Assign new IP
      gateway = "192.168.5.1";
      dns = [ "192.168.5.220" ];
    };
  };
}
```

3. **Configure switch**: Set up LACP on switch ports

4. **Build and deploy**: `just switch new-host`

### With Single NIC

Follow same steps but use:
```nix
clubcotton.systemd-network = {
  enable = true;
  mode = "single-nic";
  interfaces = [ "enp0s31f6" ];  # Your NIC name
  enableIncusBridge = false;
  enableVlans = true;
  nativeVlan = {
    # ... same as above
  };
};
```

### Adding to Different VLANs

To add additional VLANs beyond 10 and 20:

1. **Edit module** (`modules/systemd-network/default.nix`):
```nix
vlans = [
  { id = 10; subnet = "192.168.10"; }
  { id = 20; subnet = "192.168.20"; }
  { id = 30; subnet = "192.168.30"; }  # New VLAN
];
```

2. **Update switch**: Allow new VLAN on trunk ports

3. **Configure DHCP**: Add VLAN 30 to dnsmasq configuration

4. **Rebuild all hosts**: `just build-all && just deploy-all`

## Troubleshooting

### Check Network Status

```bash
# Overall network status
networkctl status

# List all network devices
networkctl list

# Check specific interface
networkctl status bond0
networkctl status br0
networkctl status br0.10

# View IP addresses
ip addr show

# View routes
ip route show
```

### Bond Status

```bash
# Check bond mode and slave status
cat /proc/net/bonding/bond0

# Should show:
# - Mode: IEEE 802.3ad Dynamic link aggregation
# - Aggregator ID: XX (same on both slaves)
# - MII Status: up
```

### VLAN Status

```bash
# List VLAN interfaces
ip -d link show type vlan

# Check VLAN IDs
ip -d link show br0.10 | grep vlan

# Test connectivity
ping -I br0 192.168.5.1      # Native VLAN
ping -I br0.10 192.168.10.1  # VLAN 10
ping -I br0.20 192.168.20.1  # VLAN 20
```

### systemd-networkd Logs

```bash
# View networkd logs
journalctl -u systemd-networkd -f

# Check for errors
journalctl -u systemd-networkd -p err

# Restart networkd
systemctl restart systemd-networkd
```

### Common Issues

#### Bond Not Forming

**Symptoms**:
- `cat /proc/net/bonding/bond0` shows slaves down
- Different Aggregator IDs on slaves

**Causes**:
- Switch LACP not configured
- Switch ports not in same LAG
- Cable issues

**Solution**:
1. Verify switch LACP configuration
2. Check both ports are in same port-channel
3. Verify cables are connected

#### VLANs Not Getting DHCP

**Symptoms**:
- VLAN interfaces UP but no IP address
- `ip addr show br0.10` shows no inet address

**Causes**:
- DHCP server not responding on VLAN
- Switch not allowing tagged VLAN traffic
- DHCP client timing out

**Solution**:
```bash
# Test DHCP manually
dhcpcd -d br0.10

# Check switch VLAN configuration
# Ensure VLANs 10 and 20 are allowed on trunk port

# Check dnsmasq is listening on VLANs
netstat -ulnp | grep :67
```

#### Incus VMs Can't Access Network

**Symptoms**:
- VM has no network connectivity
- VM can't get DHCP address

**Causes**:
- Bridge not configured correctly
- VM NIC not attached to bridge
- Firewall blocking bridge traffic

**Solution**:
```bash
# Check bridge has VMs attached
ip link show master br0

# Verify bridge forwarding
cat /sys/class/net/br0/bridge/stp_state  # Should be 0

# Check firewall rules
nft list ruleset | grep br0

# Test from host
incus exec myvm -- ip addr
```

### Performance Testing

```bash
# Test bond throughput (from another host)
iperf3 -s  # On target host
iperf3 -c 192.168.5.210 -P 4  # From test host, 4 parallel streams

# Monitor bond performance
watch -n1 cat /proc/net/bonding/bond0

# Monitor network traffic
iftop -i bond0
```

## Network Diagram

```
                    Internet
                        |
                   Router/Gateway
                   (192.168.5.1)
                        |
                  VLAN Trunk
                        |
              +---------+----------+
              |   Network Switch   |
              | (802.3ad LACP)     |
              +---------+----------+
                        |
         +--------------+----------------+----------------+
         |              |                |                |
      LACP LAG       LACP LAG         LACP LAG       Single Link
         |              |                |                |
    +----+----+    +----+----+      +----+----+      +----+----+
    | nix-01  |    | nix-02  |      | nix-03  |      | nas-01  |
    |         |    |         |      |         |      |         |
    | bond0   |    | bond0   |      | bond0   |      | enp0s.. |
    |   |     |    |   |     |      |   |     |      |   |     |
    |  br0    |    |  br0    |      |  br0    |      |  VLAN   |
    | /|\ \   |    | /|\ \   |      | /|\ \   |      |  /|\    |
    |/ | \ \  |    |/ | \ \  |      |/ | \ \  |      | / | \   |
    V  V  V V |    V  V  V V |      V  V  V V |      V  V  V   |
    5 10 20 VM|    5 10 20 VM|      5 10 20 VM|      5 10 20   |
    +---------+    +---------+      +---------+      +---------+

VLAN 5:  192.168.5.0/24   (Native/Untagged)
VLAN 10: 192.168.10.0/24  (Tagged)
VLAN 20: 192.168.20.0/24  (Tagged)
```

## References

- Module Documentation: `modules/systemd-network/README.md`
- systemd-networkd Manual: https://www.freedesktop.org/software/systemd/man/systemd.network.html
- Linux Bonding: https://www.kernel.org/doc/Documentation/networking/bonding.txt
- 802.3ad LACP: IEEE Standard 802.3ad
