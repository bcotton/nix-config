#!/usr/bin/env bash
# provision-incus-ssd.sh - Migrate Incus storage to dedicated SSDs
#
# Repurposes unused Ceph SSDs on nix-01/02/03 as dedicated Incus storage.
# Run from local machine (e.g., admin). SSHes into each host.
#
# Usage: ./scripts/provision-incus-ssd.sh

set -euo pipefail

# Host -> SSD device mapping (by-id for stability)
declare -A SSD_DEVICES=(
  [nix-01]="/dev/disk/by-id/nvme-CT1000P3PSSD8_2239E66FC077"
  [nix-02]="/dev/disk/by-id/nvme-CT1000P3PSSD8_2239E66FC07A"
  [nix-03]="/dev/disk/by-id/nvme-CT1000P3PSSD8_2239E66FC0A5"
)

HOSTS=("nix-01" "nix-02" "nix-03")
CLUSTER_HOST="nix-01"  # Host to run cluster-wide Incus commands from
POOL_NAME="incus"      # ZFS pool name on each host
INCUS_POOL="local"     # Incus storage pool name (matches Terraform refs)

# SSH options - use ed25519 key with IdentitiesOnly to avoid auth failures
SSH_OPTS="-o ConnectTimeout=10 -o LogLevel=ERROR"

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
for host in "${HOSTS[@]}"; do
  if ssh_cmd "$host" "hostname" &>/dev/null; then
    echo "  $host: OK"
  else
    echo "  $host: FAILED - cannot SSH as root"
    exit 1
  fi
done

echo ""
echo "Checking Incus cluster status..."
ssh_cmd "$CLUSTER_HOST" "incus cluster list"

echo ""
echo "Checking for running instances..."
INSTANCES=$(ssh_cmd "$CLUSTER_HOST" "incus list --format csv 2>/dev/null" || true)
if [ -n "$INSTANCES" ]; then
  echo "WARNING: Running instances found:"
  echo "$INSTANCES"
  echo "All instances will be lost. Proceed with caution."
else
  echo "  No running instances - safe to proceed."
fi

echo ""
echo "Verifying SSDs are visible and NOT in use..."
for host in "${HOSTS[@]}"; do
  DISK="${SSD_DEVICES[$host]}"
  echo "  $host: checking $DISK"

  # Check device exists
  if ! ssh_cmd "$host" "test -e $DISK"; then
    echo "    FATAL: device not found"
    exit 1
  fi

  RESOLVED=$(ssh_cmd "$host" "readlink -f $DISK")
  SIZE=$(ssh_cmd "$host" "lsblk -dno SIZE $RESOLVED 2>/dev/null || echo unknown")

  # Safety check 1: not part of any ZFS pool (especially rpool)
  ZPOOL_MEMBER=$(ssh_cmd "$host" "zpool status -L 2>/dev/null | grep -F '$RESOLVED' || true")
  if [ -n "$ZPOOL_MEMBER" ]; then
    echo "    FATAL: $RESOLVED is part of an active ZFS pool:"
    echo "    $ZPOOL_MEMBER"
    exit 1
  fi

  # Safety check 2: no mounted filesystems on any partition
  MOUNTS=$(ssh_cmd "$host" "lsblk -no MOUNTPOINT $RESOLVED 2>/dev/null | grep -v '^$' || true")
  if [ -n "$MOUNTS" ]; then
    echo "    FATAL: $RESOLVED has mounted filesystems:"
    echo "    $MOUNTS"
    exit 1
  fi

  # Safety check 3: confirm it has Ceph/LVM signatures (expected state)
  FSTYPE=$(ssh_cmd "$host" "lsblk -dno FSTYPE $RESOLVED 2>/dev/null || true")
  if [[ "$FSTYPE" == *"LVM2_member"* ]]; then
    echo "    OK: $RESOLVED ($SIZE) - has old Ceph LVM signatures as expected"
  elif [ -z "$FSTYPE" ]; then
    echo "    OK: $RESOLVED ($SIZE) - disk is clean (no signatures)"
  else
    echo "    WARNING: $RESOLVED ($SIZE) - unexpected filesystem type: $FSTYPE"
    echo "    Expected LVM2_member (old Ceph) or empty"
    read -rp "    Continue anyway? (y/N) " answer
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
      exit 1
    fi
  fi

  # Safety check 4: confirm it is NOT the device backing rpool
  RPOOL_DISK=$(ssh_cmd "$host" "zpool status -L rpool 2>/dev/null | grep -oP '/dev/\S+' | head -1 || true")
  RPOOL_BASE=$(ssh_cmd "$host" "echo $RPOOL_DISK | sed 's/p[0-9]*$//' || true")
  if [ "$RESOLVED" = "$RPOOL_BASE" ]; then
    echo "    FATAL: $RESOLVED is the root pool (rpool) device!"
    exit 1
  fi
  echo "    Confirmed: rpool is on $RPOOL_BASE (different device)"
done

echo ""
echo "Current Incus storage pool:"
ssh_cmd "$CLUSTER_HOST" "incus storage list" || true

# ── Phase A: Tear down old Incus storage ────────────────────────────

confirm "PHASE A: Tear down old Incus storage pool (from $CLUSTER_HOST)"

phase_header "PHASE A: TEAR DOWN OLD INCUS STORAGE"

# Check if storage pool exists at all
if ! ssh_cmd "$CLUSTER_HOST" "incus storage show $INCUS_POOL &>/dev/null"; then
  echo "Storage pool '$INCUS_POOL' does not exist - skipping Phase A."
else

echo "Deleting cached images..."
IMAGES=$(ssh_cmd "$CLUSTER_HOST" "incus image list --format csv 2>/dev/null | cut -d, -f2" || true)
if [ -n "$IMAGES" ]; then
  for fingerprint in $IMAGES; do
    echo "  Deleting image $fingerprint..."
    ssh_cmd "$CLUSTER_HOST" "incus image delete $fingerprint" || true
  done
else
  echo "  No cached images to delete."
fi

echo ""
echo "Removing storage pool references from profiles..."
PROFILES=$(ssh_cmd "$CLUSTER_HOST" "incus profile list --format csv 2>/dev/null | cut -d, -f1" || true)
for profile in $PROFILES; do
  # Check if profile has a root device referencing the local pool
  HAS_ROOT=$(ssh_cmd "$CLUSTER_HOST" "incus profile device list $profile 2>/dev/null | grep -c root || true")
  if [ "$HAS_ROOT" -gt 0 ] 2>/dev/null; then
    echo "  Removing root device from profile: $profile"
    ssh_cmd "$CLUSTER_HOST" "incus profile device remove $profile root" || true
  fi
done

echo ""
echo "Cleaning up ZFS datasets on each member before pool deletion..."
for host in "${HOSTS[@]}"; do
  SOURCE=$(ssh_cmd "$host" "incus storage get $INCUS_POOL source 2>/dev/null || true")
  if [ -z "$SOURCE" ]; then
    echo "  $host: no storage source found, skipping"
    continue
  fi

  echo "  $host: source=$SOURCE"

  # Determine if source is a ZFS dataset (e.g. rpool/incus) or a loopback pool
  IS_LOOPBACK=false
  if [[ "$SOURCE" == /* ]]; then
    # Loopback file path - pool is a standalone ZFS pool (likely named 'local')
    IS_LOOPBACK=true
    ZFS_ROOT=$(ssh_cmd "$host" "zpool list -Ho name 2>/dev/null | grep -v rpool | head -1 || true")
    echo "    Loopback-backed pool: $ZFS_ROOT"
  else
    ZFS_ROOT="$SOURCE"
  fi

  if [ -z "$ZFS_ROOT" ] || ! ssh_cmd "$host" "zfs list $ZFS_ROOT &>/dev/null"; then
    echo "    ZFS root $ZFS_ROOT not found, skipping"
    continue
  fi

  # Stop Incus so it doesn't hold datasets busy or recreate them
  echo "    Stopping Incus..."
  ssh_cmd "$host" "systemctl stop incus.socket incus.service; sleep 2"

  # Remove storage-pool directory (can hold datasets busy via delegation)
  ssh_cmd "$host" "rm -rf /var/lib/incus/storage-pools/$INCUS_POOL/" || true

  if [ "$IS_LOOPBACK" = true ]; then
    # For loopback pools: destroy the entire ZFS pool and the backing file
    echo "    Destroying loopback ZFS pool '$ZFS_ROOT'..."
    ssh_cmd "$host" "zpool destroy -f $ZFS_ROOT 2>/dev/null || true"
    ssh_cmd "$host" "rm -f $SOURCE"
  else
    # For dataset-backed pools: promote clones, then destroy recursively
    echo "    Destroying ZFS datasets under $ZFS_ROOT..."
    ssh_cmd "$host" "
      # Promote any clones to break snapshot dependencies
      for ds in \$(zfs list -H -r -o name,origin $ZFS_ROOT 2>/dev/null | grep -v '\-\$' | awk '{print \$1}'); do
        zfs promote \"\$ds\" 2>/dev/null || true
      done
      # Force-destroy everything recursively
      zfs destroy -Rf $ZFS_ROOT 2>/dev/null || true
    "
  fi

  # Restart Incus
  echo "    Restarting Incus..."
  ssh_cmd "$host" "systemctl start incus.socket incus.service; sleep 2"
done

echo ""
echo "Deleting storage pool '$INCUS_POOL'..."
ssh_cmd "$CLUSTER_HOST" "incus storage delete $INCUS_POOL"
echo "  Storage pool deleted."

fi  # end storage pool exists check

# ── Phase B: Prepare SSDs ───────────────────────────────────────────

confirm "PHASE B: Wipe old Ceph data and create ZFS pools on SSDs"

phase_header "PHASE B: PREPARE SSDs"

for host in "${HOSTS[@]}"; do
  DISK="${SSD_DEVICES[$host]}"
  echo "--- $host: $DISK ---"

  echo "  Wiping old Ceph/LVM signatures..."
  ssh_cmd "$host" "
    # Remove LVM volume groups if present
    VG=\$(pvs --noheadings -o vg_name $DISK 2>/dev/null | tr -d ' ' || true)
    if [ -n \"\$VG\" ]; then
      echo '    Removing LVM VG: '\$VG
      vgremove -f \$VG || true
    fi

    # Remove LVM PV
    pvremove -f $DISK 2>/dev/null || true

    # Wipe filesystem signatures
    wipefs -a $DISK

    # Zap GPT/MBR
    sgdisk --zap-all $DISK

    echo '    Disk wiped.'
  "

  echo "  Creating ZFS pool '$POOL_NAME'..."
  ssh_cmd "$host" "
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
      $POOL_NAME $DISK
  "

  echo "  Verifying..."
  ssh_cmd "$host" "zpool status $POOL_NAME | head -5"
  ssh_cmd "$host" "zpool list $POOL_NAME"
  echo ""
done

# ── Phase C: Recreate Incus storage pool ────────────────────────────

confirm "PHASE C: Recreate Incus storage pool using new ZFS pools"

phase_header "PHASE C: RECREATE INCUS STORAGE POOL"

echo "Registering per-member storage sources..."
for host in "${HOSTS[@]}"; do
  echo "  $host: source=$POOL_NAME"
  ssh_cmd "$CLUSTER_HOST" "incus storage create $INCUS_POOL zfs source=$POOL_NAME --target $host"
done

echo ""
echo "Finalizing storage pool creation..."
ssh_cmd "$CLUSTER_HOST" "incus storage create $INCUS_POOL zfs"

echo ""
echo "Restoring default profile root disk..."
ssh_cmd "$CLUSTER_HOST" "incus profile device add default root disk pool=$INCUS_POOL path=/"

echo ""
echo "Verifying storage pool..."
ssh_cmd "$CLUSTER_HOST" "incus storage list"
echo ""
ssh_cmd "$CLUSTER_HOST" "incus storage info $INCUS_POOL"

echo ""
echo "Testing with a container..."
ssh_cmd "$CLUSTER_HOST" "incus launch images:ubuntu/24.04 migration-test"
sleep 5
ssh_cmd "$CLUSTER_HOST" "incus list"
ssh_cmd "$CLUSTER_HOST" "incus delete migration-test --force"
echo "  Test container created and deleted successfully."

echo ""
echo "Cluster status:"
ssh_cmd "$CLUSTER_HOST" "incus cluster list"

# ── Phase D: Cleanup old storage ────────────────────────────────────

confirm "PHASE D: Cleanup old ZFS volumes and loopback files"

phase_header "PHASE D: CLEANUP OLD STORAGE"

echo "Destroying old rpool/incus dataset on nix-01..."
ssh_cmd "nix-01" "
  if zfs list rpool/incus &>/dev/null; then
    zfs destroy -r rpool/incus
    echo '  Destroyed rpool/incus'
  else
    echo '  rpool/incus does not exist (already cleaned up)'
  fi
"

echo ""
echo "Destroying old rpool/local/incus zvol on each host..."
for host in "${HOSTS[@]}"; do
  echo "  $host:"
  ssh_cmd "$host" "
    if zfs list rpool/local/incus &>/dev/null; then
      zfs destroy rpool/local/incus
      echo '    Destroyed rpool/local/incus'
    else
      echo '    rpool/local/incus does not exist (already cleaned up)'
    fi
  "
done

echo ""
echo "Removing old loopback files on nix-02 and nix-03..."
for host in "nix-02" "nix-03"; do
  echo "  $host:"
  ssh_cmd "$host" "
    if [ -f /var/lib/incus/disks/local.img ]; then
      rm -f /var/lib/incus/disks/local.img
      echo '    Removed /var/lib/incus/disks/local.img'
    else
      echo '    No loopback file found'
    fi
  "
done

echo ""
echo "Space reclaimed on rpool:"
for host in "${HOSTS[@]}"; do
  echo "  $host:"
  ssh_cmd "$host" "zpool list rpool"
done

# ── Done ────────────────────────────────────────────────────────────

phase_header "MIGRATION COMPLETE"

echo "Summary:"
echo "  - Old Incus storage pool torn down"
echo "  - SSDs wiped and ZFS pools created"
echo "  - Incus storage pool 'local' recreated on new ZFS pools"
echo "  - Old zvols and loopback files cleaned up"
echo ""
echo "Next steps:"
echo "  1. Update NixOS configs (remove old zvol, add boot.zfs.extraPools)"
echo "  2. Deploy: just deploy nix-01 nix-02 nix-03"
echo "  3. Reboot each host one at a time to verify pool auto-imports"
