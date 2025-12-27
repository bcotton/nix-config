#!/usr/bin/env bash
set -euo pipefail

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
CURRENT_VERSION=$(grep -oP 'version = "\K[^"]+' "$OVERLAY_FILE")
echo -e "${BLUE}Current version: ${CURRENT_VERSION}${NC}"

if [[ "$LATEST_VERSION" == "$CURRENT_VERSION" ]]; then
    echo -e "${GREEN}Already at latest version!${NC}"
    exit 0
fi

echo -e "${YELLOW}==> Updating to version ${LATEST_VERSION}...${NC}"

# Step 1: Update version number
echo -e "${BLUE}==> Updating version in ${OVERLAY_FILE}...${NC}"
sed -i "s/version = \"[^\"]*\";/version = \"${LATEST_VERSION}\";/" "$OVERLAY_FILE"

# Step 2: Get source hash
echo -e "${BLUE}==> Fetching source hash...${NC}"
SOURCE_URL="https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${LATEST_VERSION}.tgz"
SOURCE_HASH=$(nix-prefetch-url --unpack "$SOURCE_URL" 2>/dev/null)
SOURCE_HASH_SRI="sha256-${SOURCE_HASH}"

echo -e "${GREEN}Source hash: ${SOURCE_HASH_SRI}${NC}"

# Step 3: Update source hash
echo -e "${BLUE}==> Updating source hash...${NC}"
sed -i "s|hash = \"sha256-[^\"]*\";|hash = \"${SOURCE_HASH_SRI}\";|" "$OVERLAY_FILE"

# Step 4: Set npmDepsHash to fake hash
echo -e "${BLUE}==> Setting npmDepsHash to lib.fakeHash for build...${NC}"
sed -i 's/npmDepsHash = "sha256-[^"]*";/npmDepsHash = lib.fakeHash;/' "$OVERLAY_FILE"

# Step 5: Build to get correct npmDepsHash
echo -e "${BLUE}==> Building to get correct npmDepsHash (this will fail, that's expected)...${NC}"
if BUILD_OUTPUT=$(just build 2>&1); then
    echo -e "${RED}Warning: Build succeeded unexpectedly with fake hash${NC}"
    NPM_DEPS_HASH="lib.fakeHash"
else
    # Parse the error output for the correct hash
    NPM_DEPS_HASH=$(echo "$BUILD_OUTPUT" | grep -oP 'got:\s+sha256-\K[A-Za-z0-9+/=]+' | head -1)

    if [[ -z "$NPM_DEPS_HASH" ]]; then
        echo -e "${RED}Error: Could not extract npmDepsHash from build output${NC}"
        echo -e "${YELLOW}Build output:${NC}"
        echo "$BUILD_OUTPUT"
        exit 1
    fi

    NPM_DEPS_HASH="sha256-${NPM_DEPS_HASH}"
    echo -e "${GREEN}Found npmDepsHash: ${NPM_DEPS_HASH}${NC}"
fi

# Step 6: Update with correct npmDepsHash
echo -e "${BLUE}==> Updating npmDepsHash...${NC}"
sed -i "s|npmDepsHash = lib.fakeHash;|npmDepsHash = \"${NPM_DEPS_HASH}\";|" "$OVERLAY_FILE"

# Step 7: Build again to verify
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
