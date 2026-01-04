# Quick Start: Forgejo Setup

## What's Been Created

I've created a complete Forgejo module following the clubcotton service patterns:

### Module Structure
```
clubcotton/services/forgejo/
├── default.nix      # Module entry point
├── service.nix      # Main Forgejo service
└── runner.nix       # Forgejo Actions runners
```

### Configuration Added

1. **nas-01** (hosts/nixos/nas-01/default.nix)
   - Forgejo service enabled
   - ZFS dataset: `/ssdpool/local/forgejo` (200GB quota, lz4 compression)
   - PostgreSQL database on ssdpool
   - HTTP port: 3000, SSH port: 2222
   - Accessible via Tailscale and local network (192.168.5.0/24)

2. **nix-01, nix-02, nix-03** (hosts/nixos/nix-0X/default.nix)
   - 2 runners per host (6 total)
   - Docker-based execution
   - Support for: nixos, ubuntu-latest, debian-latest
   - 2 parallel jobs per runner (12 total capacity)

## Required Secrets

Before deploying, you need to create these secrets using agenix. See FORGEJO.md for detailed instructions.

### Temporarily Disabled

The secret references in the host configurations are currently enabled but will cause build failures until you create the secrets. You have two options:

**Option 1: Create secrets now (Recommended)**
```bash
# Generate database password
openssl rand -base64 32 > /tmp/forgejo-db-password

# Encrypt with agenix (requires age configuration)
agenix -e secrets/forgejo-db-password.age
# Paste the password and save

# Update secrets/secrets.nix to add:
"forgejo-db-password.age".publicKeys = allKeys;

# Add age.secrets configuration to nas-01
# See FORGEJO.md for complete instructions
```

**Option 2: Comment out secret references**
In hosts/nixos/nas-01/default.nix, change line 318 to:
```nix
# passwordFile = config.age.secrets."forgejo-db-password".path;
passwordFile = "/run/secrets/forgejo-db-password"; # Placeholder - create secret!
```

And in nix-01,02,03/default.nix, comment out the tokenFile lines:
```nix
# tokenFile = config.age.secrets."forgejo-runner-token".path;
tokenFile = "/run/secrets/forgejo-runner-token"; # Placeholder - configure after deployment
```

## Next Steps

1. **Review configuration**
   - Check FORGEJO.md for detailed documentation
   - Review the module options in service.nix

2. **Create secrets** (see FORGEJO.md)

3. **Deploy in order:**
   ```bash
   # 1. Deploy Forgejo on nas-01
   just build nas-01  # Test build
   just switch nas-01 # Deploy

   # 2. Access Forgejo and complete setup
   # http://nas-01.lan:3000

   # 3. Generate runner token in Forgejo admin panel

   # 4. Create runner token secret

   # 5. Deploy runners
   just switch nix-01
   just switch nix-02
   just switch nix-03
   ```

4. **Verify deployment**
   - Access Forgejo web UI
   - Check runners in Admin → Actions → Runners
   - Test a simple workflow

## Documentation

- **FORGEJO.md** - Complete deployment guide with:
  - Architecture overview
  - Secrets configuration
  - Deployment procedure
  - Troubleshooting
  - Performance tuning
  - Security considerations

## Module Features

The module supports all the features you requested:

- Local PostgreSQL database on ssdpool
- Git LFS for large files
- Forgejo Actions (CI/CD)
- Package registry (container, npm, etc.)
- Distributed runners on nix-01,02,03
- Tailscale + local network access
- Automatic database creation
- ZFS storage with compression
- Integration with clubcotton patterns

## Questions?

Refer to FORGEJO.md for:
- Detailed setup instructions
- Secret management
- Troubleshooting steps
- Maintenance procedures
- Example workflows
