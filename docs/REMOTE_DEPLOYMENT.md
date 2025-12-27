# Remote Deployment Options

## Nixinate Status

### Issue
Nixinate's app structure is incompatible with the Nix flake schema:
- Nixinate returns nested apps: `apps.${system}.nixinate.${hostname}`
- Flake schema expects flat apps: `apps.${system}.${appname}`
- This causes `nix flake check` and `nix flake show` to fail

### Current Configuration
The flake still includes nixinate metadata in system builders:
- Each NixOS configuration has `_module.args.nixinate` with: host, sshUser, buildOn, hermetic
- This metadata is unused without the apps interface

### Workaround in Justfile
The `just check` command temporarily comments out `apps.nixinate` before running `nix flake check`.

## Alternative Remote Deployment Methods

### Option 1: nixos-rebuild with SSH (Recommended)
Built-in NixOS remote deployment using standard SSH:

```bash
# Deploy from local machine to remote host
nixos-rebuild switch --flake .#hostname \
  --target-host root@hostname.lan \
  --build-host localhost

# Or build on remote (requires nix on remote)
nixos-rebuild switch --flake .#hostname \
  --target-host root@hostname.lan
```

**Pros:**
- Built into NixOS, no additional tools
- Well-documented and widely used
- Works with existing flake structure

**Cons:**
- Manual per-host deployment
- No built-in parallelization

**Justfile Integration:**
```just
deploy hostname:
  nixos-rebuild switch --flake .#{{hostname}} \
    --target-host root@{{hostname}}.lan \
    --build-host localhost
```

### Option 2: Colmena
Purpose-built deployment tool for NixOS flakes with multi-host support:

```nix
# Add to flake inputs
inputs.colmena.url = "github:zhaofengli/colmena";

# Create colmena.nix or add to flake
{
  meta = {
    nixpkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
  };

  # Convert nixosConfigurations to colmena format
  admin = { name, nodes, ... }: {
    deployment = {
      targetHost = "admin.lan";
      targetUser = "root";
      buildOnTarget = false;
    };
    imports = [ self.nixosConfigurations.admin.config ];
  };
  # ... other hosts
}
```

**Commands:**
```bash
colmena apply          # Deploy to all hosts
colmena apply --on admin  # Deploy to specific host
colmena build          # Build all configurations
```

**Pros:**
- Designed for multi-host deployments
- Parallel deployment support
- Health checks and rollback
- Good progress reporting

**Cons:**
- Additional dependency
- Requires colmena-specific configuration
- Learning curve

### Option 3: deploy-rs
Modern deployment tool with excellent flake support:

```nix
# Add to flake inputs
inputs.deploy-rs.url = "github:serokell/deploy-rs";

# Add to flake outputs
{
  deploy.nodes.admin = {
    hostname = "admin.lan";
    profiles.system = {
      user = "root";
      path = deploy-rs.lib.x86_64-linux.activate.nixos
        self.nixosConfigurations.admin;
    };
  };
  # ... other hosts
}
```

**Commands:**
```bash
deploy .#admin         # Deploy specific host
deploy                 # Deploy all hosts
```

**Pros:**
- Modern, actively maintained
- Good flake integration
- Supports multiple profiles per host
- Automatic rollback on failure

**Cons:**
- Additional configuration needed
- Another tool to learn

### Option 4: Simple SSH Script
Custom deployment script using standard tools:

```bash
#!/usr/bin/env bash
# deploy.sh
HOST=$1
FLAKE_REF="${2:-.}"

nix build "${FLAKE_REF}#nixosConfigurations.${HOST}.config.system.build.toplevel"
nix copy --to ssh://root@${HOST}.lan ./result
ssh root@${HOST}.lan "nix-env --profile /nix/var/nix/profiles/system --set $(readlink ./result) && $(readlink ./result)/bin/switch-to-configuration switch"
```

**Pros:**
- Simple, transparent
- No additional dependencies
- Full control over process

**Cons:**
- Manual implementation
- No built-in safety features
- Limited error handling

## Recommendation

For this flake, I recommend **Option 1 (nixos-rebuild with SSH)**:

1. **Add Justfile Commands:**
   ```just
   # Deploy to specific host
   deploy hostname:
     nixos-rebuild switch --flake .#{{hostname}} \
       --target-host root@{{hostname}}.lan \
       --build-host localhost

   # Deploy to all hosts (sequential)
   deploy-all:
     #!/usr/bin/env bash
     for host in $(nix eval --json '.#nixosConfigurations' --apply builtins.attrNames | jq -r '.[]'); do
       echo "Deploying $host..."
       just deploy $host
     done
   ```

2. **Benefits:**
   - Works immediately with current setup
   - No additional configuration needed
   - Familiar to NixOS users
   - Reliable and well-tested

3. **Migration Path:**
   - Can easily switch to colmena or deploy-rs later if multi-host parallelization becomes important
   - Both tools can work alongside nixos-rebuild

## Removing Nixinate

If switching to an alternative, remove nixinate references:

1. **Remove from flake inputs** (flake.nix):
   ```nix
   # Remove:
   nixinate.url = "github:matthewcroughan/nixinate";
   ```

2. **Remove nixinate config from system builders** (flake-modules/hosts.nix):
   ```nix
   # Remove this module from nixosSystem and nixosMinimalSystem:
   ({ config, ... }: {
     _module.args.nixinate = { ... };
   })
   ```

3. **Update Justfile**:
   - Remove `nixinate` and `nix-all` commands
   - Remove nixinate workaround from `check` command
   - Add new deployment commands

## Testing Deployment

Before deploying to production:

1. **Test local build:**
   ```bash
   nix build '.#nixosConfigurations.hostname.config.system.build.toplevel'
   ```

2. **Test SSH access:**
   ```bash
   ssh root@hostname.lan "nixos-version"
   ```

3. **Dry run (if using nixos-rebuild):**
   ```bash
   nixos-rebuild dry-build --flake .#hostname \
     --target-host root@hostname.lan
   ```

4. **Deploy to test host first:**
   ```bash
   just deploy nixos-utm  # or another non-critical host
   ```
