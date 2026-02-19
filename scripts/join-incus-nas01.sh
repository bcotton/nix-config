#!/usr/bin/env bash
# join-incus-nas01.sh - Add nas-01 to the Incus cluster
#
# Prerequisites:
#   1. Deploy the NixOS config to nas-01 first (incus module + bridge networking)
#   2. Verify bridge is up: ssh root@nas-01 'ip addr show br0'
#
# Usage: ./scripts/join-incus-nas01.sh

set -euo pipefail

SSH_OPTS="-o ConnectTimeout=10 -o LogLevel=ERROR"
CLUSTER_HOST="nix-01"
NEW_HOST="nas-01"

ssh_cmd() {
  local host="$1"
  shift
  ssh $SSH_OPTS "root@${host}" "$@"
}

confirm() {
  local msg="$1"
  echo ""
  echo "=== $msg ==="
  read -rp "Press Enter to continue, or Ctrl-C to abort... "
  echo ""
}

phase_header() {
  echo ""
  echo "################################################################"
  echo "# $1"
  echo "################################################################"
  echo ""
}

# ── Pre-flight checks ──────────────────────────────────────────────

phase_header "PRE-FLIGHT CHECKS"

echo "Checking SSH connectivity..."
for host in "$CLUSTER_HOST" "$NEW_HOST"; do
  if ssh_cmd "$host" "hostname" &>/dev/null; then
    echo "  $host: OK"
  else
    echo "  $host: FAILED"
    exit 1
  fi
done

echo ""
echo "Checking Incus is installed on $NEW_HOST..."
if ssh_cmd "$NEW_HOST" "which incus &>/dev/null"; then
  echo "  Incus installed: OK"
else
  echo "  FATAL: Incus not found on $NEW_HOST. Deploy the NixOS config first."
  exit 1
fi

echo ""
echo "Checking bridge networking on $NEW_HOST..."
BR_IP=$(ssh_cmd "$NEW_HOST" "ip -4 addr show br0 2>/dev/null | grep -oP 'inet \K[0-9.]+' || true")
if [ -n "$BR_IP" ]; then
  echo "  Bridge br0 has IP: $BR_IP"
else
  echo "  FATAL: Bridge br0 has no IP. Deploy the NixOS config first."
  exit 1
fi

echo ""
echo "Checking current cluster status..."
ssh_cmd "$CLUSTER_HOST" "incus cluster list"

echo ""
echo "Checking zvol on $NEW_HOST..."
ssh_cmd "$NEW_HOST" "zfs list -o name,volsize,used,avail ssdpool/local/incus 2>&1 || echo 'zvol not found'"

# ── Phase 1: Resize zvol and create ZFS pool ───────────────────────

confirm "PHASE 1: Resize zvol to 1TB and create ZFS pool on it"

phase_header "PHASE 1: PREPARE STORAGE"

echo "Resizing zvol to 1TB..."
ssh_cmd "$NEW_HOST" "zfs set volsize=1T ssdpool/local/incus"
ssh_cmd "$NEW_HOST" "zfs list -o name,volsize ssdpool/local/incus"

echo ""
echo "Checking if 'incus' pool already exists..."
if ssh_cmd "$NEW_HOST" "zpool list incus &>/dev/null"; then
  echo "  Pool 'incus' already exists, skipping creation."
  ssh_cmd "$NEW_HOST" "zpool list incus"
else
  echo "  Creating ZFS pool 'incus' on zvol..."
  ssh_cmd "$NEW_HOST" "
    zpool create \\
      -o ashift=12 \\
      -o autotrim=on \\
      -O compression=lz4 \\
      -O acltype=posixacl \\
      -O xattr=sa \\
      -O dnodesize=auto \\
      -O normalization=formD \\
      -O canmount=off \\
      -O mountpoint=none \\
      incus /dev/zvol/ssdpool/local/incus
  "
  echo "  Pool created."
  ssh_cmd "$NEW_HOST" "zpool status incus"
  ssh_cmd "$NEW_HOST" "zpool list incus"
fi

# ── Phase 2: Generate join token and join cluster ──────────────────

confirm "PHASE 2: Join the Incus cluster"

phase_header "PHASE 2: JOIN CLUSTER"

echo "Generating join token from $CLUSTER_HOST..."
JOIN_TOKEN=$(ssh_cmd "$CLUSTER_HOST" "incus cluster add $NEW_HOST")
echo "  Token generated."

echo ""
echo "Joining cluster from $NEW_HOST..."
echo "  Running 'incus admin init' with preseed..."
ssh_cmd "$NEW_HOST" "cat <<'PRESEED' | incus admin init --preseed
config:
  core.https_address: 192.168.5.42:8443
cluster:
  enabled: true
  server_name: $NEW_HOST
  cluster_token: \"$JOIN_TOKEN\"
  member_config:
    - entity: storage-pool
      name: local
      key: source
      value: incus
PRESEED"

echo ""
echo "Waiting for cluster to stabilize..."
sleep 5

# ── Phase 3: Verify ───────────────────────────────────────────────

phase_header "VERIFICATION"

echo "Cluster status:"
ssh_cmd "$CLUSTER_HOST" "incus cluster list"

echo ""
echo "Storage pool on $NEW_HOST:"
ssh_cmd "$CLUSTER_HOST" "incus storage info local --target $NEW_HOST"

echo ""
echo "Testing container on $NEW_HOST..."
ssh_cmd "$CLUSTER_HOST" "incus launch images:ubuntu/24.04 test-nas01 --target $NEW_HOST"
sleep 5
ssh_cmd "$CLUSTER_HOST" "incus list"
ssh_cmd "$CLUSTER_HOST" "incus delete test-nas01 --force"
echo "  Test container created and deleted successfully."

phase_header "COMPLETE"
echo "$NEW_HOST successfully joined the Incus cluster."
echo ""
echo "Cluster members:"
ssh_cmd "$CLUSTER_HOST" "incus cluster list"
