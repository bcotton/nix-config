# AGENTS.md

This file provides guidance to agentic coding tools working with this NixOS/nix-darwin configuration repository.

## Repository Overview

This is a personal NixOS/nix-darwin flake-based configuration managing multiple machines and services across macOS and Linux systems. It uses flake-parts for modular organization, Home Manager for user configurations, and includes a comprehensive media server stack with monitoring, storage, and infrastructure services.

**Key External Documentation:**
- `CLAUDE.md` - Companion guide with overlapping but complementary information
- `flake-modules/TESTING_GUIDE.md` - Comprehensive testing and debugging guide
- `docs/` - Additional guides for specific topics (ZFS, networking, remote deployment, etc.)
- `overlays/README.md` - How to update package overlays

## Build, Test, and Lint Commands

### Building Configurations

**Important:** When running `nix` commands with `#` character in arguments (e.g., `.#darwinConfigurations.bobs-laptop.system`), always surround the argument with quotes.

```bash
# macOS (nix-darwin)
just build [hostname]              # Build without switching
just switch [hostname]             # Build and switch to new config
just trace [hostname]              # Build with --show-trace for debugging

# Linux (NixOS) - includes automatic formatting
just build [hostname]              # Build (auto-runs nix fmt)
just switch [hostname]             # Build and switch with sudo
just trace [hostname]              # Build with --show-trace

# Remote deployment
just deploy hostname               # Deploy to specific remote host
just deploy hostname1 hostname2    # Deploy to multiple hosts
just deploy-all                    # Deploy to all NixOS hosts (excludes admin)

# Build all configurations
just build-all                     # Build all NixOS configurations
just build-host hostname           # Build specific host configuration
```

### Testing

```bash
# Run all flake checks (includes all tests)
just check
nix flake check

# Run a specific test
nix build '.#checks.x86_64-linux.postgresql'
nix build '.#checks.x86_64-linux.postgresql-integration'
nix build '.#checks.x86_64-linux.webdav'
nix build '.#checks.x86_64-linux.kavita'
nix build '.#checks.x86_64-linux.harmonia'
nix build '.#checks.x86_64-linux.nix-cache-proxy'
nix build '.#checks.x86_64-linux.nix-cache-integration'
nix build '.#checks.x86_64-linux.zfs-single-root'
nix build '.#checks.x86_64-linux.zfs-raidz1'
nix build '.#checks.x86_64-linux.zfs-mirrored-root'

# Run test interactively (for debugging)
nix run '.#checks.x86_64-linux.postgresql.driverInteractive'

# Run NixOS VM for testing
just vm
nix run '.#nixosConfigurations.nixos.config.system.build.nixos-shell'
```

**Note:** Tests are only available on x86_64-linux systems.

**Important: When creating or debugging tests, force local execution to simplify iteration:**
```bash
# Disable distributed builders to run tests locally
nix flake check --option builders ''
nix build '.#checks.x86_64-linux.postgresql' --option builders ''
```

### Formatting and Linting

```bash
# Format all nix files (uses alejandra)
just fmt
nix fmt .

# Pre-commit hook automatically runs formatting
# Git hooks are auto-installed when running any just command
```

### Development Commands

```bash
just repl                          # Start nix repl with flake loaded
just update                        # Update all flake inputs
just gc [generations]              # Garbage collect (default: 5d)
```

## Code Organization and Structure

### File Organization

- **Main flake.nix** - Minimal (88 lines), imports flake-parts modules only
- **flake-modules/** - Modular flake outputs:
  - `formatter.nix` - Alejandra formatter
  - `packages.nix` - Custom packages (primp, gwtmux)
  - `overlays.nix` - Overlay exports for external consumption
  - `checks.nix` - NixOS tests (x86_64-linux only)
  - `hosts.nix` - System builders and all host configurations
  - `TESTING_GUIDE.md` - Comprehensive testing documentation
- **hosts/** - Host-specific configurations
  - `common/` - Shared configurations (packages, darwin/nixos common, lib.nix)
  - `darwin/` - macOS host configurations
  - `nixos/` - Linux host configurations
- **home/** - Home Manager user configurations
- **modules/** - Custom NixOS modules (code-server, frigate, zfs, etc.)
- **clubcotton/services/** - Service configurations for media server stack
- **overlays/** - Package overlays (each in separate file)
- **pkgs/** - Custom package definitions (each in directory with `default.nix`)
- **tests/** - Integration tests using NixOS testing framework
- **secrets/** - Age-encrypted secrets
- **users/** - User account definitions
- **docs/** - Additional documentation (ZFS, networking, remote deployment, etc.)

### Flake-Parts Architecture

This flake uses [flake-parts](https://flake.parts/) for modular organization:

- All flake outputs are defined in `flake-modules/`
- Each module handles a specific concern (hosts, packages, checks, etc.)
- Supports 4 systems: x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin

### Host Configuration System

**NixOS hosts** are defined in `flake-modules/hosts.nix` in the `nixosHostSpecs` attrset:

```nix
nixosHostSpecs = {
  hostname = {
    system = "x86_64-linux";      # Target architecture
    usernames = ["bcotton"];       # Users to create
    ip = "192.168.5.x";            # Optional: enables Glances monitoring and homepage
    displayName = "Display Name";  # Optional: shown on homepage
  };
};
```

Adding a host to `nixosHostSpecs` automatically:
- Creates the NixOS configuration
- Adds SSH RemoteForward configuration
- Adds to homepage dashboard (if IP is specified)
- Includes in `just deploy-all`

**Darwin hosts** are defined separately in `darwinConfigurations` and require manual addition.

## Nix Code Style Guidelines

### Formatting
- Use `alejandra` formatter (automatically applied via `just fmt` or `nix fmt`)
- Pre-commit hook automatically formats staged files
- Always run formatter before committing

### Module Structure
```nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.clubcotton.servicename;
in {
  options.services.clubcotton.servicename = {
    enable = mkEnableOption "Service Name";

    setting = mkOption {
      type = types.str;
      default = "value";
      description = "Description of setting.";
    };
  };

  config = mkIf cfg.enable {
    # Implementation
  };
}
```

### Imports
- Import order: `config`, `lib`, `pkgs`, `...` (additional args)
- Use `unstablePkgs` for packages from nixpkgs-unstable
- Use `localPackages` for custom packages from this flake
- Import external modules at top of module definition

### Naming Conventions
- Hosts: lowercase with hyphens (e.g., `nas-01`, `bobs-laptop`)
- Modules: lowercase with hyphens, namespace under `services.clubcotton.*` or `modules.*`
- Options: camelCase for multi-word options (e.g., `enableTCPIP`, `passwordFile`)
- Variables: camelCase in `let` bindings (e.g., `cfg`, `genPkgs`, `unstablePkgs`)
- Functions: camelCase with `mk` prefix for builders (e.g., `mkModuleArgs`, `mkHomeManagerConfig`)
- Files: lowercase with hyphens, use `default.nix` for main module file

### Types
- Always specify types for options: `types.str`, `types.bool`, `types.port`, `types.package`, etc.
- Use `mkEnableOption` for boolean enable flags
- Use `literalExpression` for code examples in descriptions
- Mark internal options with `internal = true`

### Comments
- Use `#` for single-line comments
- Add descriptions to all options
- Document non-obvious logic
- Add section comments for major blocks in large files

## Testing Approach

### Test File Structure
```nix
{nixpkgs}: {
  name = "test-name";

  nodes = {
    machine = {config, pkgs, ...}: {
      _module.args.unstablePkgs = unstablePkgs;
      imports = [../modules/mymodule];
      # Configuration
    };
  };

  testScript = ''
    start_all()

    with subtest("Description"):
        machine.wait_for_unit("service.service")
        machine.succeed("test command")
  '';
}
```

### Testing Best Practices
- Place tests in `modules/*/test.nix` for module-specific tests
- Place integration tests in `tests/` directory
- Place service tests in `clubcotton/services/<service>/test.nix`
- Use descriptive subtest names
- Test service startup, connectivity, and functionality
- Include tests in `flake-modules/checks.nix`
- **Enable SSH by default** in tests for easier debugging (see TESTING_GUIDE.md)

### Interactive Test Debugging

Standard tests have SSH enabled on port 2223:
```bash
# Start interactive test
nix run '.#checks.x86_64-linux.postgresql.driverInteractive'

# In another terminal, SSH into the VM
ssh -p 2223 root@localhost
```

See `flake-modules/TESTING_GUIDE.md` for comprehensive testing documentation.

## Service Modules

### Service Structure
- Create directory under `clubcotton/services/servicename/`
- Main configuration in `default.nix`
- Optional test file: `test.nix`
- Namespace options under `services.clubcotton.servicename`
- Add to `clubcotton/services/default.nix` imports list

### Common Patterns
- Use `mkIf cfg.enable` to conditionally apply configuration
- Define post-start commands in `postStartCommands` list
- Use systemd service definitions with proper dependencies
- Open firewall ports explicitly when needed
- Use secrets via `agenix` - never hardcode credentials
- Use `homepage.*` options for services that should appear on the homepage dashboard

### Error Handling
- Use assertions for configuration validation: `assertions = [ { assertion = ...; message = "..."; } ];`
- Provide helpful error messages in assertions
- Use `mkIf` to prevent evaluation of disabled modules
- Add warnings for deprecated options: `warnings = [ "message" ];`

## Overlays

Two overlay systems serve different purposes:

1. **flake-modules/overlays.nix** - Exports overlays as flake outputs for external consumption
   - `overlays.yq` - yq package overlay
   - `overlays.claude-code` - claude-code version pinning
   - `overlays.default` - Combined core overlays

2. **overlays.nix** - NixOS/Darwin module that conditionally applies overlays based on config
   - Core overlays: yq, beets, qmk, claude-code (always applied)
   - Conditional overlays: jellyfin, zfs smart-disk-monitoring, ctlptl, delta

### Custom Overlays

Each overlay in separate file under `overlays/`:
- `claude-code.nix` - Pins claude-code version (update via `scripts/upgrade-claude-code.sh`)
- `delta.nix` - Adds themes.gitconfig to delta package
- `jellyfin.nix` - Enables VPL for hardware acceleration
- `beets.nix`, `qmk.nix`, `yq.nix` - Tool-specific overrides

To update a package version:
1. Edit version number in overlay file
2. Update source hash using `nix-prefetch-url` or `lib.fakeHash`
3. Update `npmDepsHash` if applicable (npm packages)

See `overlays/README.md` for detailed update instructions.

## Secrets Management

Uses `agenix` for secret encryption. Secrets are defined in `secrets/secrets.nix` and encrypted files stored in `secrets/` directory.

**Important: Do NOT attempt to create, edit, or configure agenix secret files directly.**

When working with features that require secrets:
1. Add the secret definition to `secrets/secrets.nix` (this is safe - just metadata)
2. Reference the secret in your configuration using `config.age.secrets.<name>.path`
3. Leave clear instructions for the user to create/edit the actual encrypted secret file
4. Document what content/format the secret file should contain

Example instructions to provide:
```bash
# After this configuration is applied, create the secret:
agenix -e new-secret.age
# Then add the required content (e.g., password, API key, etc.)
```

See `secrets/README-NIX-CACHE.md` for an example of proper secret documentation.

## Common Workflows

### Adding a New NixOS Host

1. **Add host specification** to `nixosHostSpecs` in `flake-modules/hosts.nix`:
   ```nix
   newhost = {
     system = "x86_64-linux";
     usernames = ["bcotton"];
     ip = "192.168.5.xxx";  # Optional, for monitoring
   };
   ```

2. **Create host directory** at `hosts/nixos/newhost/` with:
   - `default.nix` - Main host configuration
   - `hardware-configuration.nix` - Hardware-specific settings
   - `disk-config.nix` - Disk partitioning (if using disko)
   - `variables.nix` - Host-specific variables

3. **Use `create-host.sh` script** as a starting point (see `hosts/create-host.sh`)

### Adding a New Service

1. Create directory `clubcotton/services/myservice/`
2. Create `default.nix` with module structure
3. Add to `clubcotton/services/default.nix` imports
4. Optionally create `test.nix` and add to `flake-modules/checks.nix`
5. Add homepage options if service should appear on dashboard

### Adding a New User

1. Create `users/username.nix` with user definition
2. Create `home/username.nix` with Home Manager configuration
3. Add username to host's `usernames` list in `nixosHostSpecs`

## Important Gotchas

### Git Add Required
**New files must be `git add`ed before nix can see them.** If you get "file not found" errors for files you just created, run:
```bash
git add new-file.nix
```

### Quote Arguments with `#`
When running nix commands with `#` in arguments, always quote them:
```bash
# Correct
nix build ".#nixosConfigurations.hostname.config.system.build.toplevel"

# Wrong - shell interprets # as comment
nix build .#nixosConfigurations.hostname.config.system.build.toplevel
```

### Pre-Commit Hooks
Git hooks are in `.githooks/` and are automatically installed when running any `just` command:
- Pre-commit hook runs `nix fmt` on staged files
- Configure via: `git config --local core.hooksPath .githooks`

### Distributed Builds
The repository uses `nix-builder-config` for distributed builds:
- All NixOS and Darwin systems have the nix-builder client enabled
- Builds are distributed to builder hosts automatically
- CI builds use SSH keys from `secrets/nix-builder-ssh-key`

### ZFS Tests Require --impure
ZFS/disko tests require the `--impure` flag due to disko's test infrastructure:
```bash
just check --impure  # Enables ZFS tests
```

### Darwin vs NixOS Differences
- Darwin uses `nix-darwin`, NixOS uses `nixos-rebuild`
- ZFS configurations only apply to NixOS (Linux)
- Some services may not work on Darwin
- Home Manager is integrated differently on each platform

## CI/CD

Uses Forgejo (self-hosted) for CI:
- `.forgejo/workflows/build-hosts.yaml` - Builds NixOS configurations on push/PR
- `.forgejo/workflows/nix-check.yaml` - Runs `nix flake check`
- CI runner image: `forgejo.bobtail-clownfish.ts.net/bcotton/nix-ci-runner:fe32792`

## Git Workflow

- Pre-commit hook runs `just fmt` automatically
- Git hooks installed automatically via `just install-hooks`
- All commits should have formatted code
- Use `just trace` for debugging build failures with full trace output

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
