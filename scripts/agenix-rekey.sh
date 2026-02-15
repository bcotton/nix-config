#!/usr/bin/env bash
# agenix-rekey.sh - Re-key all agenix secrets with a single password prompt
#
# age decrypts SSH keys directly (not via ssh-agent), so it prompts for your
# passphrase on every secret file. This script creates a temporary passphrase-free
# copy of your key, passes it to agenix, then securely deletes it.
#
# Usage: ./scripts/agenix-rekey.sh [path-to-ssh-key]
# Default key: ~/.ssh/id_ed25519

set -euo pipefail

IDENTITY="${1:-$HOME/.ssh/id_ed25519}"

if [[ ! -f "$IDENTITY" ]]; then
    echo "Error: Identity file not found: $IDENTITY" >&2
    exit 1
fi

# Read passphrase once
read -rsp "Enter passphrase for $(basename "$IDENTITY"): " PASSPHRASE
echo

# Create a temporary decrypted copy of the key
TMPKEY=$(mktemp)
chmod 600 "$TMPKEY"
trap 'rm -f "$TMPKEY"' EXIT

cp "$IDENTITY" "$TMPKEY"

# Remove passphrase from the temporary copy
if ! ssh-keygen -p -P "$PASSPHRASE" -N "" -f "$TMPKEY" >/dev/null 2>&1; then
    echo "Error: Wrong passphrase or invalid key." >&2
    exit 1
fi
unset PASSPHRASE

echo "Re-keying secrets..."
cd "$(dirname "$0")/../secrets"
agenix -r -i "$TMPKEY"

echo "Done! All secrets re-keyed."
