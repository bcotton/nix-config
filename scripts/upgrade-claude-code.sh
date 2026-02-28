#!/usr/bin/env bash
set -euo pipefail

# Upgrade claude-code to the latest npm version.
# Updates: overlays/claude-code.nix (version, src hash, npmDepsHash)
#          overlays/claude-code-package-lock.json

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

OVERLAY_FILE="overlays/claude-code.nix"
LOCKFILE="overlays/claude-code-package-lock.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

# Portable sed in-place edit (works on both macOS and Linux)
sed_inplace() {
    local pattern="$1"
    local file="$2"
    local tmp="${file}.tmp"
    sed "$pattern" "$file" > "$tmp" && mv "$tmp" "$file"
}

echo -e "${BLUE}==> Checking for latest claude-code version...${NC}"
LATEST_VERSION=$(npm view @anthropic-ai/claude-code version)
echo -e "${GREEN}Latest version: ${LATEST_VERSION}${NC}"

# Get current version from overlay
CURRENT_VERSION=$(sed -n 's/.*version = "\([^"]*\)".*/\1/p' "$OVERLAY_FILE" | head -1)
echo -e "${BLUE}Current version: ${CURRENT_VERSION}${NC}"

if [[ "$LATEST_VERSION" == "$CURRENT_VERSION" ]]; then
    echo -e "${GREEN}Already at latest version!${NC}"
    exit 0
fi

echo -e "${YELLOW}==> Updating to version ${LATEST_VERSION}...${NC}"

# Step 1: Fetch source hash
echo -e "${BLUE}==> Fetching source hash...${NC}"
SOURCE_URL="https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${LATEST_VERSION}.tgz"
SOURCE_HASH_NIX32=$(nix-prefetch-url --unpack "$SOURCE_URL" 2>/dev/null)
SOURCE_HASH_SRI=$(nix hash convert --hash-algo sha256 --to sri "$SOURCE_HASH_NIX32")
echo -e "${GREEN}Source hash: ${SOURCE_HASH_SRI}${NC}"

# Step 2: Generate package-lock.json
echo -e "${BLUE}==> Generating package-lock.json...${NC}"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
curl -sL "$SOURCE_URL" | tar xz --strip-components=1 -C "$TMPDIR"
(cd "$TMPDIR" && npm install --package-lock-only --ignore-scripts 2>/dev/null)
cp "$TMPDIR/package-lock.json" "$LOCKFILE"
echo -e "${GREEN}Lock file generated${NC}"

# Step 3: Compute npmDepsHash
echo -e "${BLUE}==> Computing npm deps hash...${NC}"
NPM_DEPS_HASH=$(nix shell nixpkgs#prefetch-npm-deps -c prefetch-npm-deps "$LOCKFILE" 2>/dev/null)
echo -e "${GREEN}npmDepsHash: ${NPM_DEPS_HASH}${NC}"

# Step 4: Update overlay
echo -e "${BLUE}==> Updating ${OVERLAY_FILE}...${NC}"
sed_inplace "s/version = \"[^\"]*\";/version = \"${LATEST_VERSION}\";/" "$OVERLAY_FILE"
sed_inplace "s|hash = \"sha256-[^\"]*\";|hash = \"${SOURCE_HASH_SRI}\";|" "$OVERLAY_FILE"
sed_inplace "s|npmDepsHash = \"sha256-[^\"]*\";|npmDepsHash = \"${NPM_DEPS_HASH}\";|" "$OVERLAY_FILE"

# Step 5: Build to verify
echo -e "${BLUE}==> Building to verify...${NC}"
if just build; then
    echo -e "${GREEN}==> Successfully upgraded claude-code from ${CURRENT_VERSION} to ${LATEST_VERSION}!${NC}"
    echo -e "${YELLOW}==> Don't forget to commit the changes:${NC}"
    echo -e "    git add ${OVERLAY_FILE} ${LOCKFILE}"
    echo -e "    git commit -m 'upgrade claude-code to ${LATEST_VERSION}'"
else
    echo -e "${RED}==> Build failed. Please check the errors above.${NC}"
    exit 1
fi
