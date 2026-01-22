# Package Overlays

This directory contains Nix overlays that modify or pin specific package versions.

## Available Overlays

### claude-code.nix
Pins claude-code to a specific version for consistent updates across systems.

**To update to a new version (automated):**

```bash
./scripts/upgrade-claude-code.sh
```

The script will automatically:
- Check for the latest version on npm
- Update the version, source hash, and npmDepsHash
- Build and verify the update
- Provide commit instructions

**To update manually:**

1. Check the latest version on npm:
   ```bash
   npm view @anthropic-ai/claude-code version
   ```

2. Update the version in `claude-code.nix`:
   ```nix
   version = "2.0.XX"; # Update this line
   ```

3. Get the new source hash:
   ```bash
   nix-prefetch-url --unpack https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-2.0.XX.tgz
   ```

4. Update the hash in the overlay:
   ```nix
   hash = "sha256-..."; # Use the hash from step 3
   ```

5. Update npmDepsHash by temporarily setting it to a fake hash:
   ```nix
   npmDepsHash = lib.fakeHash;
   ```

6. Build to get the correct hash:
   ```bash
   just build
   ```

7. Copy the correct hash from the error message and update the overlay.

8. Build again to verify:
   ```bash
   just build
   ```

### Other Overlays

- **delta.nix** - Adds themes.gitconfig to the delta package
- **jellyfin.nix** - Enables VPL (Video Processing Library) for hardware acceleration
- **beets.nix** - Custom beets configuration
- **qmk.nix** - QMK firmware customizations
- **yq.nix** - YAML processor overrides

## How Overlays Work

Overlays are composed in `../overlays.nix` which is imported by the main flake. They modify the package set before it's used to build system or home configurations.

Core overlays (like claude-code, yq, beets, qmk) are always applied, while conditional overlays (like jellyfin, smart-disk-monitoring) are only applied when the relevant service is enabled.
