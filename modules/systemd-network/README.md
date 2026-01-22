# systemd-networkd Module

This module provides a flexible systemd-networkd based networking configuration that supports:
- Single NIC or dual-NIC bonding (802.3ad LACP)
- VLAN tagging for multi-VLAN access
- Bridge networking for Incus/LXD containers and VMs
- Proper integration with Incus so VMs can access all VLANs

## Features

### Network Topologies Supported

1. **Bonded + Bridge + VLANs** (nix-01/02/03)
   - Two NICs bonded with 802.3ad (LACP)
   - Bridge on top of bond
   - VLANs (10, 20) created on bridge with DHCP
   - Native VLAN (5) gets static IP on bridge
   - Incus VMs attached to bridge can access all VLANs

2. **Single NIC + VLANs** (nas-01)
   - Single physical interface
   - VLANs (10, 20) created directly on interface with DHCP
   - Native VLAN (5) gets static IP on interface
   - Suitable for hosts without Incus

## Configuration

### Bonded Configuration with Incus (nix-01/02/03)

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

This creates:
- `bond0`: LACP bond of enp2s0 and enp3s0
- `br0`: Bridge attached to bond0 (192.168.5.210/24)
- `br0.10`: VLAN 10 interface on bridge (DHCP)
- `br0.20`: VLAN 20 interface on bridge (DHCP)

Network topology:
```
enp2s0 ─┐
        ├─ bond0 ─ br0 (192.168.5.210/24) ─┬─ br0.10 (DHCP)
enp3s0 ─┘                                   └─ br0.20 (DHCP)
                                            └─ Incus VMs
```

### Single NIC Configuration (nas-01)

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

This creates:
- `enp0s31f6`: Physical interface (192.168.5.300/24)
- `enp0s31f6.10`: VLAN 10 interface (DHCP)
- `enp0s31f6.20`: VLAN 20 interface (DHCP)

Network topology:
```
enp0s31f6 (192.168.5.300/24) ─┬─ enp0s31f6.10 (DHCP)
                              └─ enp0s31f6.20 (DHCP)
```

## Options

### `clubcotton.systemd-network.enable`
- Type: `bool`
- Default: `false`
- Enable systemd-networkd based networking

### `clubcotton.systemd-network.mode`
- Type: `enum [ "single-nic" "bonded" ]`
- Required: `true`
- Network configuration mode

### `clubcotton.systemd-network.interfaces`
- Type: `list of strings`
- Required: `true`
- List of physical interfaces to use
- Example: `[ "enp2s0" "enp3s0" ]` for bonding, `[ "enp0s31f6" ]` for single

### `clubcotton.systemd-network.bondName`
- Type: `string`
- Default: `"bond0"`
- Name of the bond device (bonded mode only)

### `clubcotton.systemd-network.bridgeName`
- Type: `string`
- Default: `"br0"`
- Name of the bridge device

### `clubcotton.systemd-network.enableIncusBridge`
- Type: `bool`
- Default: `false`
- Enable bridge for Incus/LXD VMs
- When enabled: VLANs are created on bridge
- When disabled: VLANs are created directly on interface/bond

### `clubcotton.systemd-network.enableVlans`
- Type: `bool`
- Default: `true`
- Enable VLAN interfaces (10, 20) with DHCP

### `clubcotton.systemd-network.nativeVlan`
- Type: `submodule`
- Required: `true`
- Native/untagged VLAN configuration

#### `nativeVlan.id`
- Type: `int`
- Default: `5`
- VLAN ID for native traffic (informational)

#### `nativeVlan.address`
- Type: `string`
- Required: `true`
- Static IP address with CIDR prefix
- Example: `"192.168.5.210/24"`

#### `nativeVlan.gateway`
- Type: `string`
- Required: `true`
- Default gateway
- Example: `"192.168.5.1"`

#### `nativeVlan.dns`
- Type: `list of strings`
- Default: `[ "192.168.5.220" ]`
- DNS servers

## How VLANs Work

### VLANs Defined
The module currently supports three VLANs:
- **VLAN 5** (native/untagged): Gets static IP on main interface/bridge
- **VLAN 10**: Tagged VLAN, gets DHCP address
- **VLAN 20**: Tagged VLAN, gets DHCP address

### Adding More VLANs
To add additional VLANs, edit `modules/systemd-network/default.nix`:

```nix
vlans = [
  { id = 10; subnet = "192.168.10"; }
  { id = 20; subnet = "192.168.20"; }
  { id = 30; subnet = "192.168.30"; }  # Add new VLAN here
];
```

### VLAN DHCP Configuration
VLAN interfaces (10, 20) are configured with:
- DHCP enabled
- Route metric 1024 (higher than native VLAN)
- DNS from DHCP disabled (uses native VLAN DNS)
- Default routes disabled (uses native VLAN gateway)

This ensures:
- Native VLAN is the primary network path
- VLANs are reachable but don't override main routing
- Host can communicate on all VLANs simultaneously

## Bond Configuration

When using `mode = "bonded"`, the bond is configured with:
- **Mode**: 802.3ad (LACP)
- **Transmit Hash Policy**: layer3+4 (balanced by IP + port)
- **LACP Rate**: fast (1 second)
- **MII Monitor**: 100ms

### Switch Requirements for LACP
Your network switch must support and have LACP enabled on the ports where bonded hosts connect. Configure:
- Mode: LACP (802.3ad)
- Both ports in the same LAG (Link Aggregation Group)

## Troubleshooting

### Check systemd-networkd status
```bash
systemctl status systemd-networkd
networkctl status
```

### View network configuration
```bash
networkctl list
networkctl status bond0
networkctl status br0
```

### Check bond status
```bash
cat /proc/net/bonding/bond0
```

### View VLAN interfaces
```bash
ip -d link show type vlan
```

### Check IP addresses
```bash
ip addr show
```

### Test VLAN connectivity
```bash
# Ping gateway on each VLAN
ping -I br0 192.168.5.1
ping -I br0.10 192.168.10.1
ping -I br0.20 192.168.20.1
```

## Integration with Incus

When `enableIncusBridge = true`, Incus VMs can access all VLANs by:

1. Attaching VM network to `br0` bridge
2. Configuring VLAN interfaces inside the VM

Example Incus profile for multi-VLAN VM:
```bash
incus profile create multi-vlan
incus profile edit multi-vlan << EOF
devices:
  eth0:
    name: eth0
    nictype: bridged
    parent: br0
    type: nic
EOF
```

Inside the VM, configure VLANs:
```bash
# Native VLAN (untagged on br0)
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

Or use cloud-init/systemd-networkd inside the VM for automatic configuration.
