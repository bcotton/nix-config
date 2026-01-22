#!/usr/bin/env bash
#
# Regenerate Nix binary cache and builder secrets
# Run this script from the secrets/ directory
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Nix Cache Secret Regeneration ==="
echo ""
echo "This will generate NEW secrets for:"
echo "  1. Binary cache signing key (harmonia-signing-key.age)"
echo "  2. SSH builder key pair (nix-builder-ssh-key.age, nix-builder-ssh-pub.age)"
echo ""
echo "WARNING: This will overwrite existing secrets!"
echo ""
read -p "Continue? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 1
fi

# Clean up any existing temporary files
rm -f /tmp/cache-priv /tmp/cache-pub /tmp/builder-key /tmp/builder-key.pub

echo ""
echo "=== Step 1: Generating binary cache signing key ==="
nix-store --generate-binary-cache-key nas-01-cache /tmp/cache-priv /tmp/cache-pub

echo "Private key generated: /tmp/cache-priv"
echo "Public key generated: /tmp/cache-pub"
echo ""

# Read the keys
PRIVATE_KEY=$(cat /tmp/cache-priv | tr -d '\n')
PUBLIC_KEY=$(cat /tmp/cache-pub | tr -d '\n')

echo "Public key (save this for client configuration):"
echo "$PUBLIC_KEY"
echo ""

# Save public key to reference file (not encrypted)
echo -n "$PUBLIC_KEY" > cache-public-key.txt
echo "Saved to: cache-public-key.txt"
echo ""

echo "=== Step 2: Encrypting private signing key with agenix ==="
# Create a temporary script to edit the secret non-interactively
cat > /tmp/agenix-edit-cache.sh << 'EDITEOF'
#!/usr/bin/env bash
TEMP_FILE="$1"
echo -n "${CACHE_PRIVATE_KEY}" > "$TEMP_FILE"
EDITEOF
chmod +x /tmp/agenix-edit-cache.sh

# Export for the editor script
export CACHE_PRIVATE_KEY="$PRIVATE_KEY"
EDITOR=/tmp/agenix-edit-cache.sh agenix -e harmonia-signing-key.age

echo "Encrypted to: harmonia-signing-key.age"
echo ""

echo "=== Step 3: Generating SSH builder keypair ==="
ssh-keygen -t ed25519 -f /tmp/builder-key -N "" -C "nix-builder@nas-01"
echo "SSH keypair generated"
echo ""

SSH_PRIVATE=$(cat /tmp/builder-key)
SSH_PUBLIC=$(cat /tmp/builder-key.pub)

echo "SSH public key:"
echo "$SSH_PUBLIC"
echo ""

echo "=== Step 4: Encrypting SSH private key with agenix ==="
cat > /tmp/agenix-edit-ssh-priv.sh << 'EDITEOF'
#!/usr/bin/env bash
TEMP_FILE="$1"
# SSH keys MUST end with a newline
printf '%s\n' "${SSH_PRIVATE_KEY}" > "$TEMP_FILE"
EDITEOF
chmod +x /tmp/agenix-edit-ssh-priv.sh

export SSH_PRIVATE_KEY="$SSH_PRIVATE"
EDITOR=/tmp/agenix-edit-ssh-priv.sh agenix -e nix-builder-ssh-key.age

echo "Encrypted to: nix-builder-ssh-key.age"
echo ""

echo "=== Step 5: Encrypting SSH public key with agenix ==="
cat > /tmp/agenix-edit-ssh-pub.sh << 'EDITEOF'
#!/usr/bin/env bash
TEMP_FILE="$1"
echo -n "${SSH_PUBLIC_KEY}" > "$TEMP_FILE"
EDITEOF
chmod +x /tmp/agenix-edit-ssh-pub.sh

export SSH_PUBLIC_KEY="$SSH_PUBLIC"
EDITOR=/tmp/agenix-edit-ssh-pub.sh agenix -e nix-builder-ssh-pub.age

echo "Encrypted to: nix-builder-ssh-pub.age"
echo ""

# Clean up
rm -f /tmp/cache-priv /tmp/cache-pub /tmp/builder-key /tmp/builder-key.pub
rm -f /tmp/agenix-edit-*.sh
unset CACHE_PRIVATE_KEY SSH_PRIVATE_KEY SSH_PUBLIC_KEY

echo "=== Step 6: Updating configurations automatically ==="
echo ""

# Update cache public key in flake-modules/hosts.nix
FLAKE_HOSTS="../flake-modules/hosts.nix"
if [ -f "$FLAKE_HOSTS" ]; then
    echo "Updating cache public key in $FLAKE_HOSTS..."
    # Update NixOS section
    sed -i "s|publicKey = \"nas-01-cache:[^\"]*\";|publicKey = \"$PUBLIC_KEY\";|g" "$FLAKE_HOSTS"
    echo "✓ Updated cache public keys in flake-modules/hosts.nix"
else
    echo "⚠ Warning: Could not find $FLAKE_HOSTS"
fi

# Update SSH public keys in host configurations
echo ""
echo "Updating SSH public keys in host configurations..."

for host in nas-01 nix-01 nix-02 nix-03; do
    HOST_CONFIG="../hosts/nixos/$host/default.nix"
    if [ -f "$HOST_CONFIG" ]; then
        # Find and replace the ssh-ed25519 key in the nix-builder authorizedKeys section
        sed -i "s|ssh-ed25519 AAAA[^ ]* nix-builder@nas-01|$SSH_PUBLIC|g" "$HOST_CONFIG"
        echo "✓ Updated $host"
    else
        echo "⚠ Warning: Could not find $HOST_CONFIG"
    fi
done

echo ""
echo "=== Summary ==="
echo ""
echo "✓ Binary cache signing key: harmonia-signing-key.age"
echo "✓ SSH builder private key: nix-builder-ssh-key.age"
echo "✓ SSH builder public key: nix-builder-ssh-pub.age"
echo "✓ Public key reference: cache-public-key.txt"
echo "✓ Updated flake-modules/hosts.nix with cache public key"
echo "✓ Updated host SSH keys: nas-01, nix-01, nix-02, nix-03"
echo ""
echo "Cache public key: $PUBLIC_KEY"
echo "SSH public key: $SSH_PUBLIC"
echo ""
echo "=== Next Steps ==="
echo ""
echo "1. Review the changes:"
echo "   git diff"
echo ""
echo "2. Commit the secrets and configuration updates:"
echo "   git add harmonia-signing-key.age nix-builder-ssh-key.age nix-builder-ssh-pub.age cache-public-key.txt"
echo "   git add flake-modules/hosts.nix hosts/nixos/*/default.nix"
echo "   git commit -m 'Rotate nix cache and builder secrets'"
echo ""
echo "3. Deploy to all hosts:"
echo "   just switch nas-01"
echo "   just switch nix-01"
echo "   just switch nix-02"
echo "   just switch nix-03"
echo ""
