# HAOS Migration: Moving Home Assistant to Incus VM

Steps to migrate the production Home Assistant from the standalone machine (192.168.20.20) to the Incus HAOS VM (prod-homeassistant).

## Current State

| Item | Old HA (standalone) | HAOS VM (prod-homeassistant) |
|------|--------------------|-----------------------------|
| Main LAN IP | N/A | 192.168.5.20 (DHCP reservation) |
| VLAN 20 IP | 192.168.20.20 | Dynamic (currently ~192.168.20.19) |
| VLAN 20 MAC | E4:5F:01:40:8D:61 | 00:16:3e:3d:95:f2 |
| DNS (homeassistant.lan) | A record -> 192.168.20.20 | N/A |
| DNS (prod-homeassistant.lan) | N/A | A record -> 192.168.5.20 |

## Goal

After migration, the HAOS VM takes over 192.168.20.20 on VLAN 20 so all IoT devices, automations, and DNS (`homeassistant.lan`) point to the new VM with no client-side changes.

## Prerequisites

- HAOS VM is fully configured: SSH access, VLANs, firewall (via `scripts/haos-setup.sh`)
- Home Assistant restored/configured on the HAOS VM (integrations, automations, etc.)
- Main LAN reservation (192.168.5.20) already deployed on dns-01

## Migration Steps

### 1. Shut down the old Home Assistant machine

Power off the standalone HA device. This releases the 192.168.20.20 DHCP lease and avoids IP conflicts.

### 2. Update VLAN 20 DHCP reservation on dns-01

In `hosts/nixos/dns-01/default.nix`, find the VLAN 20 reservation for `homeassistant`:

```nix
# Before:
{
  scope = "vlan20";
  macAddress = "E4:5F:01:40:8D:61";
  ipAddress = "192.168.20.20";
  hostName = "homeassistant";
}

# After:
{
  scope = "vlan20";
  macAddress = "00:16:3e:3d:95:f2";
  ipAddress = "192.168.20.20";
  hostName = "homeassistant";
}
```

The MAC changes to the HAOS VM's NIC (`00:16:3e:3d:95:f2`). This is the same MAC used on all VLANs since the VM has a single bridged NIC with VLAN sub-interfaces created inside the guest.

### 3. Update dnsmasq fallback DHCP hosts

In `modules/dnsmasq/dhcp-hosts.list`, update the VLAN 20 entry:

```
# Before:
E4:5F:01:40:8D:61,192.168.20.20,homeassistant

# After:
00:16:3e:3d:95:f2,192.168.20.20,homeassistant
```

### 4. Deploy dns-01

```bash
just deploy dns-01
```

This activates the new DHCP reservation. The DNS A record for `homeassistant.lan` already points to `192.168.20.20` and does not need to change.

### 5. Renew VLAN 20 DHCP lease on HAOS

SSH into the HAOS base OS and bounce the VLAN 20 connection:

```bash
ssh -i ~/.ssh/haos_ed25519 -p 22222 root@192.168.5.20

nmcli connection down enp5s0.20
nmcli connection up enp5s0.20
```

Or from your workstation:

```bash
ssh -i ~/.ssh/haos_ed25519 -p 22222 root@192.168.5.20 \
  "nmcli connection down enp5s0.20 && nmcli connection up enp5s0.20"
```

### 6. Verify

```bash
# Check HAOS got the correct VLAN 20 IP
ssh -i ~/.ssh/haos_ed25519 -p 22222 root@192.168.5.20 \
  "ip -4 addr show enp5s0.20"
# Should show: inet 192.168.20.20/24

# Check DNS resolves correctly
dig +short homeassistant.lan @192.168.5.220
# Should return: 192.168.20.20

# Check HA is reachable from main LAN
curl -s -o /dev/null -w "%{http_code}" http://192.168.20.20:8123
# Should return: 200 (or 302)
```

## What Does NOT Need to Change

- **DNS `homeassistant.lan`**: Already points to 192.168.20.20 (the IP we're taking over)
- **DNS `prod-homeassistant.lan`**: Points to 192.168.5.20 (main LAN, separate scope)
- **Main LAN reservation**: 192.168.5.20 with MAC 00:16:3e:3d:95:f2 (different DHCP scope, unaffected)
- **Firewall rules**: Use interface names (`enp5s0.20`), not IPs, so the IP change is transparent
- **IoT devices**: They communicate with 192.168.20.20 which stays the same

## Rollback

If something goes wrong:

1. Shut down or disconnect the HAOS VM from the network
2. Revert the MAC in dns-01 back to `E4:5F:01:40:8D:61`
3. Revert the MAC in `dhcp-hosts.list`
4. Deploy dns-01: `just deploy dns-01`
5. Power on the old HA machine — it will reclaim 192.168.20.20
