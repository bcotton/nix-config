# DNS Architecture

This document describes the DNS architecture for the homelab, focusing on dns-01's role as the authoritative DNS server and its interaction with Tailscale MagicDNS.

## Overview

- **Authoritative DNS**: Technitium on dns-01 (192.168.5.220) serves `.lan` zones
- **Tailscale MagicDNS**: Resolves `.ts.net` domains via 100.100.100.100 (virtual tun device)
- **Upstream forwarders**: Cloudflare (1.1.1.1) and Google (8.8.4.4) for public DNS
- **All hosts**: Point at dns-01 for DNS via `networking.nameservers` or `systemd-network.nativeVlan.dns`

## dns-01 DNS Stack

dns-01 is special: it **is** the DNS server, so its own `/etc/resolv.conf` must point at Technitium (127.0.0.1), not at itself via the network.

### Components and Their Interactions

```
                     ┌─────────────────────────┐
                     │       dns-01 host        │
                     │                          │
  resolv.conf ──────►│  Technitium (0.0.0.0:53) │
  nameserver 127.0.0.1│    │                     │
                     │    ├── .lan zones (auth)  │
                     │    ├── .ts.net ──► MagicDNS (100.100.100.100)
                     │    └── everything else ──► 1.1.1.1 / 8.8.4.4
                     │                          │
                     │  systemd-resolved        │
                     │    DNSStubListener=no     │
                     │    (D-Bus only, for TS)   │
                     └──────────────────────────┘
```

### Why DNSStubListener=no

systemd-resolved's stub listener binds `127.0.0.53:53` (TCP), which conflicts with Technitium's wildcard `0.0.0.0:53` TCP bind. The options are:

1. **`services.resolved.enable = false`** — Breaks Tailscale D-Bus split-DNS integration. Tailscale takes over `/etc/resolv.conf` with only MagicDNS (100.100.100.100), which can't resolve `.lan`. This caused a 7+ hour log outage (issue #95).

2. **`DNSStubListener=no`** (current) — Disables only the stub listener while keeping resolved running for Tailscale's D-Bus integration. Requires a manual `resolv.conf` override since the default `stub-resolv.conf` points at the now-disabled stub.

### resolv.conf Override

With `DNSStubListener=no`, resolved's default symlink (`/run/systemd/resolve/stub-resolv.conf` → `127.0.0.53`) is useless. We override it with `lib.mkForce`:

```nix
environment.etc."resolv.conf" = lib.mkForce {
  mode = "0644";
  text = ''
    nameserver 127.0.0.1
    search lan bobtail-clownfish.ts.net
  '';
};
```

`lib.mkForce` is required because resolved's NixOS module also sets `environment.etc."resolv.conf".source`.

### Conditional Forwarder for Tailscale

Go programs (like Grafana Alloy) read `/etc/resolv.conf` directly — they don't use NSS or D-Bus. So even with resolved running, Tailscale split-DNS doesn't help them. Technitium needs to know how to resolve `.ts.net` domains:

```nix
conditionalForwarders = [
  {
    zone = "bobtail-clownfish.ts.net";
    forwarder = "100.100.100.100";  # Tailscale MagicDNS
  }
];
```

This creates a Forwarder zone in Technitium that sends `.ts.net` queries to MagicDNS. MagicDNS runs on a virtual tun device (100.100.100.100) and does **not** conflict with Technitium's port 53 bind.

## Technitium Module

The Technitium module (`clubcotton/services/technitium/`) manages:

- **Authoritative zones**: `.lan` with A, CNAME, PTR records
- **Conditional forwarders**: Per-domain forwarding (e.g., `.ts.net` → MagicDNS)
- **DHCP**: Scopes and reservations
- **Ad blocking**: Block lists

### Conditional Forwarders Option

```nix
services.clubcotton.technitium.conditionalForwarders = [
  {
    zone = "example.ts.net";        # Domain to forward
    forwarder = "192.168.1.1";      # Nameserver to forward to
    protocol = "Udp";               # Optional: Udp (default), Tcp, Tls, Https
  }
];
```

Forwarder zones are created idempotently — re-running the configuration service is safe.

## Other Hosts

All other NixOS hosts use systemd-resolved normally (with its stub listener) and point at dns-01 for DNS. Tailscale's D-Bus integration adds MagicDNS as a split-DNS resolver automatically.

```nix
# Typical host DNS config (via systemd-network module)
clubcotton.systemd-network.nativeVlan.dns = ["192.168.5.220"];
```

## Monitoring: HostLogsMissing Alert

The dns-01 log outage (issue #95) exposed a monitoring gap: Prometheus could still scrape dns-01 via Tailscale, so `HostDown` never fired, but Alloy couldn't push logs to Loki because it couldn't resolve `nas-01.lan`.

### loki-host-monitor Module

A systemd timer on nas-01 (`modules/loki-host-monitor/`) runs every 5 minutes and queries Loki for each expected host:

```
count_over_time({job="systemd-journal", hostname="<host>"}[1h])
```

Results are written as a Prometheus textfile collector metric:

```
loki_host_log_lines_1h{hostname="dns-01"} 4523
loki_host_log_lines_1h{hostname="nas-01"} 12847
```

### Alert Rule

```yaml
- alert: HostLogsMissing
  expr: loki_host_log_lines_1h == 0
  for: 30m
  labels:
    severity: warning
  annotations:
    summary: "No logs from {{ $labels.hostname }}"
    description: >
      Host {{ $labels.hostname }} has not sent any logs to Loki
      in the last hour. Check alloy-logs.service on the host.
```

### Configuration

Enabled on nas-01 (where Loki runs):

```nix
services.loki-host-monitor = {
  enable = true;
  lokiUrl = "http://localhost:3100";
  expectedHosts = ["admin" "dns-01" "imac-01" "nas-01" "nix-01" "nix-02" "nix-03" "octoprint"];
};
```

When adding or removing hosts from the fleet, update the `expectedHosts` list.

## Troubleshooting

### dns-01 Can't Resolve .lan

```bash
# Check resolv.conf points at Technitium
cat /etc/resolv.conf  # Should show nameserver 127.0.0.1

# Test Technitium directly
dig @127.0.0.1 nas-01.lan +short  # Should return IP

# Check resolved status
resolvectl status  # Should show DNSStubListener=no
```

### dns-01 Can't Resolve .ts.net

```bash
# Check conditional forwarder exists
dig @127.0.0.1 forgejo.bobtail-clownfish.ts.net +short

# If it fails, check Technitium zone config
curl -sf 'http://localhost:5380/api/zones/list?token=...' | jq '.response.zones[].name'
```

### Alloy Dropping Logs

```bash
# Check Alloy can resolve Loki endpoint
dig nas-01.lan @127.0.0.1 +short

# Check Alloy service status
journalctl -u alloy.service --since "1 hour ago" | grep -i "misbehaving\|error\|retry"
```

### HostLogsMissing Alert Firing

1. SSH to the affected host
2. Check `alloy-logs.service`: `systemctl status alloy-logs.service`
3. Check DNS resolution: `dig nas-01.lan +short`
4. Check Loki reachability: `curl -sf http://nas-01.lan:3100/ready`

## History

- **PR #93**: Disabled systemd-resolved entirely to fix Technitium TCP port 53 conflict. This worked for Technitium but broke `.lan` resolution when Tailscale overwrote resolv.conf.
- **Issue #95**: dns-01 stopped sending logs for 7+ hours. Root cause: Alloy couldn't resolve `nas-01.lan` via MagicDNS. No alert fired because Prometheus scraped dns-01 via Tailscale (still reachable).
- **Current fix**: `DNSStubListener=no` + resolv.conf override + conditional forwarder + HostLogsMissing alert.
