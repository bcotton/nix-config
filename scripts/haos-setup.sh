#!/usr/bin/env bash
# haos-setup.sh - Configure SSH access, VLAN networking, and firewall on HAOS VM
#
# After reimporting the HAOS image (new VM), run this script to:
# 1. Inject SSH public key via incus agent (no reboot required)
# 2. Create VLAN sub-interfaces for multi-VLAN access
# 3. Deploy nftables firewall rules
#
# Prerequisites:
# - HAOS VM (prod-homeassistant) running in the Incus cluster
# - SSH access to the Incus host (nix-01.lan)
#
# Usage: ./scripts/haos-setup.sh [--ssh-only] [--vlan-only] [--firewall-only]
#
# See docs/HAOS_SETUP.md for full documentation.

set -euo pipefail

# --- Configuration (override via environment variables) ---
INCUS_HOST="${INCUS_HOST:-nix-01.lan}"
VM_NAME="${VM_NAME:-prod-homeassistant}"
HAOS_IP="${HAOS_IP:-192.168.5.20}"
HAOS_SSH_PORT="${HAOS_SSH_PORT:-22222}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/haos_ed25519}"
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"

# VLANs to configure (id:subnet pairs)
VLANS=(
  "10:192.168.10.0/24"
  "20:192.168.20.0/24"
)

# --- Helpers ---
info()  { echo "==> $*"; }
warn()  { echo "WARNING: $*" >&2; }
die()   { echo "ERROR: $*" >&2; exit 1; }

ssh_incus() { ssh $SSH_OPTS "root@${INCUS_HOST}" "$@"; }
ssh_haos()  { ssh $SSH_OPTS -i "$SSH_KEY" -p "$HAOS_SSH_PORT" "root@${HAOS_IP}" "$@"; }

# SSH to the cluster node where the VM is actually running.
# In a cluster, disk source paths must exist on the VM's node.
vm_node() {
  ssh_incus "incus info $VM_NAME 2>/dev/null | grep '^Location:' | awk '{print \$2}'"
}
ssh_vm_node() {
  local node
  node=$(vm_node)
  if [ -z "$node" ]; then
    die "Could not determine which node $VM_NAME is on"
  fi
  ssh $SSH_OPTS "root@${node}" "$@"
}

wait_for_ssh() {
  local max_attempts=20
  local attempt=0
  info "Waiting for HAOS SSH (port $HAOS_SSH_PORT) to become available..."
  while [ $attempt -lt $max_attempts ]; do
    if ssh $SSH_OPTS -i "$SSH_KEY" -p "$HAOS_SSH_PORT" "root@${HAOS_IP}" "true" 2>/dev/null; then
      info "SSH is ready"
      return 0
    fi
    attempt=$((attempt + 1))
    echo "  Attempt $attempt/$max_attempts..."
    sleep 5
  done
  die "SSH did not become available after $((max_attempts * 5)) seconds"
}

# --- SSH Key Setup ---
setup_ssh_key() {
  info "Setting up SSH access to HAOS base OS"

  # Generate key if needed
  if [ ! -f "$SSH_KEY" ]; then
    info "Generating SSH key pair at $SSH_KEY"
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "haos-access"
  else
    info "Using existing SSH key: $SSH_KEY"
  fi

  # Check if SSH already works
  if ssh $SSH_OPTS -i "$SSH_KEY" -p "$HAOS_SSH_PORT" "root@${HAOS_IP}" "true" 2>/dev/null; then
    info "SSH access already working, skipping key injection"
    return 0
  fi

  info "SSH not yet configured, injecting key via incus agent"

  # Check VM exists and is running
  local vm_status
  vm_status=$(ssh_incus "incus info $VM_NAME 2>/dev/null | grep '^Status:' | awk '{print \$2}'" || echo "NOT_FOUND")
  if [ "$vm_status" != "RUNNING" ]; then
    die "VM $VM_NAME is not running (status: $vm_status)"
  fi

  # Push SSH public key directly via incus exec (uses the incus agent inside the VM).
  # /root/.ssh/ is on the writable overlay partition in HAOS.
  info "Writing SSH public key to $VM_NAME via incus exec"
  ssh_incus "incus exec $VM_NAME -- mkdir -p /root/.ssh"
  cat "${SSH_KEY}.pub" | ssh_incus "incus exec $VM_NAME -- tee /root/.ssh/authorized_keys >/dev/null"
  ssh_incus "incus exec $VM_NAME -- chmod 700 /root/.ssh"
  ssh_incus "incus exec $VM_NAME -- chmod 600 /root/.ssh/authorized_keys"

  # HAOS dropbear reads authorized_keys at boot only — must restart
  info "Restarting $VM_NAME for SSH key to take effect"
  ssh_incus "incus restart $VM_NAME --timeout 120"
  sleep 30
  wait_for_ssh

  info "SSH access configured successfully"
}

# --- VLAN Setup ---
setup_vlans() {
  info "Configuring VLAN interfaces inside HAOS"

  # Load 8021q module
  ssh_haos "modprobe 8021q 2>/dev/null || true"

  for vlan_entry in "${VLANS[@]}"; do
    local vlan_id="${vlan_entry%%:*}"
    local vlan_subnet="${vlan_entry##*:}"
    local conn_name="enp5s0.${vlan_id}"

    # Check if connection already exists
    if ssh_haos "nmcli connection show '$conn_name'" &>/dev/null; then
      info "VLAN $vlan_id ($conn_name) already configured"

      # Ensure it's active
      if ! ssh_haos "nmcli device status | grep -q '$conn_name.*connected'" 2>/dev/null; then
        info "  Activating $conn_name"
        ssh_haos "nmcli connection up '$conn_name'"
      fi
      continue
    fi

    info "Creating VLAN $vlan_id interface ($conn_name, subnet $vlan_subnet)"
    ssh_haos "nmcli connection add type vlan con-name '$conn_name' ifname '$conn_name' \
      dev enp5s0 id $vlan_id ipv4.method auto ipv6.method disabled"
    ssh_haos "nmcli connection up '$conn_name'"
  done

  info "VLAN configuration complete"
}

# --- Firewall Setup ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIREWALL_RULES="${SCRIPT_DIR}/haos-firewall.nft"

setup_firewall() {
  info "Deploying nftables firewall rules to HAOS"

  if [ ! -f "$FIREWALL_RULES" ]; then
    die "Firewall rules not found at $FIREWALL_RULES"
  fi

  # Deploy rules file to persistent data partition
  ssh_haos "mkdir -p /mnt/data/firewall"
  cat "$FIREWALL_RULES" | ssh_haos "cat > /mnt/data/firewall/haos-firewall.nft"

  # Deploy loader script
  ssh_haos "printf '#!/bin/sh\n/sbin/nft -f /mnt/data/firewall/haos-firewall.nft 2>/mnt/data/firewall/last-load.log\n' > /mnt/data/firewall/load.sh && chmod +x /mnt/data/firewall/load.sh"

  # Deploy udev rule for boot persistence (overlay partition, survives updates)
  if ssh_haos "test -f /etc/udev/rules.d/90-haos-firewall.rules" 2>/dev/null; then
    info "Udev rule already exists, updating"
  fi
  ssh_haos "printf 'ACTION==\"add\", SUBSYSTEM==\"net\", KERNEL==\"enp5s0\", RUN+=\"/bin/sh -c /mnt/data/firewall/load.sh\"\n' > /etc/udev/rules.d/90-haos-firewall.rules"

  # Load rules now
  info "Loading firewall rules"
  ssh_haos "/sbin/nft -f /mnt/data/firewall/haos-firewall.nft" || die "Failed to load firewall rules"

  info "Firewall deployed and active"
}

# --- Verification ---
verify() {
  info "Verifying configuration"

  echo ""
  echo "Network devices:"
  ssh_haos "nmcli device status"

  echo ""
  echo "IP addresses:"
  ssh_haos "ip -4 addr show enp5s0 | grep inet"
  for vlan_entry in "${VLANS[@]}"; do
    local vlan_id="${vlan_entry%%:*}"
    ssh_haos "ip -4 addr show enp5s0.${vlan_id} | grep inet" 2>/dev/null || \
      warn "No IP on VLAN $vlan_id"
  done

  echo ""
  echo "ARP neighbors (VLAN reachability):"
  for vlan_entry in "${VLANS[@]}"; do
    local vlan_id="${vlan_entry%%:*}"
    local neighbors
    neighbors=$(ssh_haos "ip neigh show dev enp5s0.${vlan_id}" 2>/dev/null || echo "")
    if [ -n "$neighbors" ]; then
      echo "  VLAN $vlan_id: $(echo "$neighbors" | wc -l) neighbor(s) discovered"
    else
      warn "VLAN $vlan_id: no neighbors yet (may take a moment)"
    fi
  done

  echo ""
  echo "Firewall:"
  if ssh_haos "nft list table inet haos-firewall" &>/dev/null; then
    local drop_iot drop_guest
    drop_iot=$(ssh_haos "nft list chain inet haos-firewall input" 2>/dev/null | grep 'enp5s0.20.*drop' | grep -oP 'packets \K[0-9]+' || echo "0")
    drop_guest=$(ssh_haos "nft list chain inet haos-firewall input" 2>/dev/null | grep 'enp5s0.10.*drop' | grep -oP 'packets \K[0-9]+' || echo "0")
    echo "  Active: yes"
    echo "  IoT VLAN drops: $drop_iot packets"
    echo "  Guest VLAN drops: $drop_guest packets"
  else
    warn "Firewall not loaded"
  fi

  echo ""
  info "Done. Connect with: ssh -i $SSH_KEY -p $HAOS_SSH_PORT root@$HAOS_IP"
}

# --- Main ---
main() {
  local ssh_only=false
  local vlan_only=false
  local firewall_only=false

  for arg in "$@"; do
    case "$arg" in
      --ssh-only)      ssh_only=true ;;
      --vlan-only)     vlan_only=true ;;
      --firewall-only) firewall_only=true ;;
      --help|-h)
        echo "Usage: $0 [--ssh-only] [--vlan-only] [--firewall-only]"
        echo ""
        echo "Options:"
        echo "  --ssh-only       Only set up SSH access (skip VLAN and firewall)"
        echo "  --vlan-only      Only set up VLANs (SSH must already work)"
        echo "  --firewall-only  Only deploy firewall rules (SSH must already work)"
        echo ""
        echo "With no flags, runs the full setup: SSH + VLANs + firewall + verify."
        exit 0
        ;;
      *) die "Unknown argument: $arg" ;;
    esac
  done

  if $firewall_only; then
    setup_firewall
    verify
  elif $vlan_only; then
    setup_vlans
    verify
  elif $ssh_only; then
    setup_ssh_key
  else
    setup_ssh_key
    setup_vlans
    setup_firewall
    verify
  fi
}

main "$@"
