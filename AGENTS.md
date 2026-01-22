# AGENTS.md

This file provides guidance to agentic coding tools working with this NixOS/nix-darwin configuration repository.

## Repository Overview

This is a personal NixOS/nix-darwin flake-based configuration managing multiple machines and services across macOS and Linux systems. It uses flake-parts for modular organization, Home Manager for user configurations, and includes a comprehensive media server stack with monitoring, storage, and infrastructure services.

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

## Code Style Guidelines

### File Organization

- **Main flake.nix** - Minimal (69 lines), imports flake-parts modules only
- **flake-modules/** - Modular flake outputs (formatter, packages, overlays, checks, hosts)
- **hosts/** - Host-specific configurations (common, darwin, nixos subdirectories)
- **modules/** - Custom NixOS modules, each in its own directory with `default.nix`
- **clubcotton/services/** - Service configurations for media server stack
- **overlays/** - Package overlays (each in separate file)
- **pkgs/** - Custom package definitions (each in directory with `default.nix`)
- **tests/** - Integration tests using NixOS testing framework
- **secrets/** - Age-encrypted secrets

### Nix Code Style

**Formatting:**
- Use `alejandra` formatter (automatically applied via `just fmt` or `nix fmt`)
- Pre-commit hook automatically formats staged files
- Always run formatter before committing

**Module Structure:**
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

**Imports:**
- Import order: `config`, `lib`, `pkgs`, `...` (additional args)
- Use `unstablePkgs` for packages from nixpkgs-unstable
- Use `localPackages` for custom packages from this flake
- Import external modules at top of module definition

**Naming Conventions:**
- Hosts: lowercase with hyphens (e.g., `nas-01`, `bobs-laptop`)
- Modules: lowercase with hyphens, namespace under `services.clubcotton.*` or `modules.*`
- Options: camelCase for multi-word options (e.g., `enableTCPIP`, `passwordFile`)
- Variables: camelCase in `let` bindings (e.g., `cfg`, `genPkgs`, `unstablePkgs`)
- Functions: camelCase with `mk` prefix for builders (e.g., `mkModuleArgs`, `mkHomeManagerConfig`)
- Files: lowercase with hyphens, use `default.nix` for main module file

**Types:**
- Always specify types for options: `types.str`, `types.bool`, `types.port`, `types.package`, etc.
- Use `mkEnableOption` for boolean enable flags
- Use `literalExpression` for code examples in descriptions
- Mark internal options with `internal = true`

**Comments:**
- Use `#` for single-line comments
- Add descriptions to all options
- Document non-obvious logic
- Add section comments for major blocks in large files

### Testing

**Test File Structure:**
```nix
{
  nixpkgs,
  unstablePkgs,
  inputs,
}: {
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

**Testing Best Practices:**
- Place tests in `modules/*/test.nix` for module-specific tests
- Place integration tests in `tests/` directory
- Use descriptive subtest names
- Test service startup, connectivity, and functionality
- Include tests in `flake-modules/checks.nix`

### Service Modules

**Service Structure:**
- Create directory under `modules/servicename/`
- Main configuration in `default.nix`
- Optional test file: `test.nix`
- Namespace options under `services.clubcotton.servicename`

**Common Patterns:**
- Use `mkIf cfg.enable` to conditionally apply configuration
- Define post-start commands in `postStartCommands` list
- Use systemd service definitions with proper dependencies
- Open firewall ports explicitly when needed
- Use secrets via `agenix` - never hardcode credentials

### Error Handling

- Use assertions for configuration validation: `assertions = [ { assertion = ...; message = "..."; } ];`
- Provide helpful error messages in assertions
- Use `mkIf` to prevent evaluation of disabled modules
- Add warnings for deprecated options: `warnings = [ "message" ];`

### Overlays

- Each overlay in separate file under `overlays/`
- Export overlays via `flake-modules/overlays.nix`
- Apply overlays via `overlays.nix` module (conditionally based on config)
- Use `overrideAttrs` or `override` as appropriate
- Update hashes when changing versions: use `lib.fakeHash` initially, then replace with correct hash from build error

### Secrets Management

- Use `agenix` for all secrets
- Define secrets in `secrets/secrets.nix`
- Reference secrets via `config.age.secrets.secretname.path`
- Never commit unencrypted secrets
- Use `passwordFile` options for service credentials

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
