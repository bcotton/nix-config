#!/usr/bin/env bash
set -euo pipefail

# Portable sed in-place edit (works on both macOS and Linux)
sed_inplace() {
    local pattern="$1"
    local file="$2"
    local tmp="${file}.tmp"
    sed "$pattern" "$file" > "$tmp" && mv "$tmp" "$file"
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

OVERLAY_FILE="overlays/claude-code.nix"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

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

# Step 1: Update version number
echo -e "${BLUE}==> Updating version in ${OVERLAY_FILE}...${NC}"
sed_inplace "s/version = \"[^\"]*\";/version = \"${LATEST_VERSION}\";/" "$OVERLAY_FILE"

# Step 2: Get source hash
echo -e "${BLUE}==> Fetching source hash...${NC}"
SOURCE_URL="https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${LATEST_VERSION}.tgz"
SOURCE_HASH_NIX32=$(nix-prefetch-url --unpack "$SOURCE_URL" 2>/dev/null)
# Convert nix32 hash to SRI format
SOURCE_HASH_SRI=$(nix hash to-sri --type sha256 "$SOURCE_HASH_NIX32")

echo -e "${GREEN}Source hash: ${SOURCE_HASH_SRI}${NC}"

# Step 3: Update source hash
echo -e "${BLUE}==> Updating source hash...${NC}"
sed_inplace "s|hash = \"sha256-[^\"]*\";|hash = \"${SOURCE_HASH_SRI}\";|" "$OVERLAY_FILE"

# Step 4: Build to verify (npmDepsHash = lib.fakeHash works for this package)
echo -e "${BLUE}==> Building to verify...${NC}"
if just build; then
    echo -e "${GREEN}==> Successfully upgraded claude-code from ${CURRENT_VERSION} to ${LATEST_VERSION}!${NC}"
    echo -e "${YELLOW}==> Don't forget to commit the changes:${NC}"
    echo -e "    git add ${OVERLAY_FILE}"
    echo -e "    git commit -m 'Upgrade claude-code to ${LATEST_VERSION}'"
else
    echo -e "${RED}==> Build failed. Please check the errors above.${NC}"
    exit 1
fi
