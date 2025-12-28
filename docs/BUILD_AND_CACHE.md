# Nix Binary Cache and Distributed Build System

## Overview

This repository includes a comprehensive distributed build and binary cache infrastructure:

- **Harmonia Binary Cache** - Fast Rust-based cache server running on `nas-01`
- **Distributed Build Fleet** - SSH-based remote builders (nas-01, nix-01, nix-02, nix-03)
- **Automatic Cache Population** - Post-build hooks sign and cache all builds
- **Tailscale Integration** - Secure access via `nix-cache` hostname

### Architecture

```
┌─────────────────────────────────────────────────────┐
│                     nas-01                          │
│  ┌──────────────┐        ┌──────────────────┐      │
│  │   Harmonia   │◄───────┤ Build Coordinator │      │
│  │ Binary Cache │        │  (SSH Builders)   │      │
│  │   :5000      │        │                   │      │
│  └──────┬───────┘        └─────────┬─────────┘      │
│         │                          │                 │
│         │ Tailscale               │ SSH             │
│         │ (nix-cache)             │                 │
└─────────┼──────────────────────────┼─────────────────┘
          │                          │
          │                          ├─────► nix-01 (builder)
          │                          ├─────► nix-02 (builder)
          │                          └─────► nix-03 (builder)
          │
          └────► All clients (NixOS + Darwin)
```

### Cache Details

- **URL**: `http://nix-cache` (via Tailscale) or `http://nas-01:5000` (direct)
- **Storage**: `/ssdpool/local/nix-cache` (500GB quota, ZFS with snapshots)
- **Public Key**: See `secrets/cache-public-key.txt` or extract with:
  ```bash
  cd secrets/ && cat cache-public-key.txt
  ```

---

## Adding Hosts as Cache Clients

All hosts can benefit from the cache without being builders. This speeds up builds and reduces redundant compilation.

### NixOS Hosts

#### 1. Add Module Import

Edit your host configuration (e.g., `hosts/nixos/hostname/default.nix`):

```nix
{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../../modules/nix-builder  # Add this line
    # ... other imports
  ];

  # ... rest of configuration
}
```

#### 2. Enable Cache Client

Add after your `services.clubcotton` block:

```nix
# Enable cache client to use nas-01 cache
services.nix-builder.client = {
  enable = true;
  cacheUrl = "http://nas-01:5000"; 
  publicKey = "nas-01-cache:GCH0WJSbH2MNoaXeyV5Qs+r4jHiGUFFO5c0/Vg0Hx8Y=";  # From secrets/cache-public-key.txt
};
```

#### 3. Deploy

```bash
just switch hostname
# or
just deploy hostname
```

#### 4. Verify

```bash
ssh hostname
nix show-config | grep substituters
# Should show: http://nas-01:5000 https://cache.nixos.org

# Test cache access
curl http://nix-cache/nix-cache-info
```

### Darwin/macOS Hosts

#### 1. Add Module Import

Edit your Darwin host configuration (e.g., `hosts/darwin/hostname/default.nix`):

```nix
{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../../modules/nix-builder/client.nix  # Add this line
    # ... other imports
  ];

  # ... rest of configuration
}
```

#### 2. Enable Cache Client

```nix
# Enable cache client
services.nix-builder.client = {
  enable = true;
  cacheUrl = "http://nas-01:5000";
  publicKey = "nas-01-cache:YOUR_PUBLIC_KEY_HERE";
};
```

#### 3. Deploy

```bash
just switch hostname
```

#### 4. Verify

```bash
nix show-config | grep substituters
# Should show: http://nix-cache https://cache.nixos.org

# Test cache access
curl http://nix-cache/nix-cache-info
```

---

## Adding Hosts as Builders

Builders not only use the cache but also contribute build capacity to the distributed fleet.

### Prerequisites

- Host must be a NixOS system
- Host must have SSH enabled
- Host must be accessible from nas-01 via SSH

### Configuration Steps

#### 1. Add Module Import and Cache Client

Follow the "NixOS Hosts" steps above to add the module and enable the cache client.

#### 2. Create Builder User

Add this configuration to the host:

```nix
# Create builder user for remote builds
users.users.nix-builder = {
  isNormalUser = true;
  description = "Nix remote builder";
  openssh.authorizedKeys.keys = [
    (builtins.readFile config.age.secrets.nix-builder-ssh-pub.path)
  ];
};

nix.settings.trusted-users = ["nix-builder"];
```

#### 3. Update nas-01 Build Coordinator

Edit `hosts/nixos/nas-01/default.nix` and add the new builder to the fleet:

```nix
services.nix-builder.coordinator = {
  enable = true;
  enableLocalBuilds = true;
  builders = [
    # ... existing builders ...
    {
      hostname = "new-builder-hostname";
      systems = ["x86_64-linux"];
      maxJobs = 4;                    # Adjust based on CPU cores
      speedFactor = 1;                # Relative speed (1-3, higher = faster)
      supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    }
  ];
};
```

**Builder Settings:**
- `maxJobs`: Number of parallel builds (typically number of CPU cores)
- `speedFactor`: Relative performance weight (1=normal, 2=fast, 3=very fast)
- `supportedFeatures`:
  - `nixos-test` - Can run NixOS VM tests
  - `benchmark` - Can run performance tests
  - `big-parallel` - Has resources for large parallel builds
  - `kvm` - Has KVM virtualization support

#### 4. Deploy to Both Hosts

```bash
# Deploy to nas-01 (coordinator)
just switch nas-01

# Deploy to the new builder
just switch new-builder-hostname
```

#### 5. Test SSH Connectivity

From nas-01:

```bash
ssh nas-01
ssh -i /run/agenix/nix-builder-ssh-key nix-builder@new-builder-hostname 'nix-store --version'
```

If this works, distributed builds will work.

#### 6. Test Distributed Build

On nas-01, trigger a build:

```bash
nix-build '<nixpkgs>' -A hello -v
```

Watch the output - you should see builds being sent to remote builders:

```
building '/nix/store/xxx-hello.drv' on 'ssh://nix-builder@new-builder-hostname'...
```

---

## nixos-anywhere Integration

When using `nixos-anywhere` to provision new hosts, the cache and builder setup can be included from the start.

### Prerequisites

1. Host configuration already exists in `hosts/nixos/hostname/default.nix`
2. Host configuration includes cache client setup (see above)
3. Secrets are properly configured

### Basic nixos-anywhere Deployment

```bash
# Deploy new host with nixos-anywhere
nix run github:nix-community/nixos-anywhere -- \
  --flake .#hostname \
  root@target-ip
```

The cache client configuration will be deployed automatically if it's in the host's `default.nix`.

### Verifying Cache After Deployment

After nixos-anywhere completes:

```bash
# SSH to the new host
ssh root@hostname

# Verify cache is configured
nix show-config | grep substituters
# Should include: http://nix-cache

# Test cache access
curl http://nix-cache/nix-cache-info

# Test a build (should use cache)
nix-build '<nixpkgs>' -A hello
```

### Adding as Builder After Deployment

If you want the new host to also be a builder:

1. Follow the "Adding Hosts as Builders" section above
2. Update nas-01's coordinator configuration
3. Deploy updates to both hosts

### Example Complete Configuration

Here's a complete example for a new NixOS host that uses the cache:

```nix
# hosts/nixos/new-host/default.nix
{
  config,
  pkgs,
  lib,
  hostName,
  ...
}: let
  commonLib = import ../../common/lib.nix;
  variables = commonLib.getHostVariables hostName;
in {
  imports = [
    ./hardware-configuration.nix
    ../../../modules/node-exporter
    ../../../modules/nix-builder  # Cache and builder support
  ];

  # Enable cache client
  services.nix-builder.client = {
    enable = true;
    cacheUrl = "http://nix-cache";
    publicKey = "nas-01-cache:GCH0WJSbH2MNoaXeyV5Qs+r4jHiGUFFO5c0/Vg0Hx8Y=";
  };

  # Optional: Make this host a builder too
  users.users.nix-builder = {
    isNormalUser = true;
    description = "Nix remote builder";
    openssh.authorizedKeys.keys = [
      (builtins.readFile config.age.secrets.nix-builder-ssh-pub.path)
    ];
  };

  nix.settings.trusted-users = ["nix-builder"];

  # Standard host configuration
  networking = {
    hostName = "new-host";
    hostId = "12345678";  # Generate with: head -c 8 /dev/urandom | od -An -t x4
    useDHCP = false;
    # ... network config
  };

  # ... rest of configuration
}
```

### nixos-anywhere with Pre-existing Secrets

If the host needs access to the builder SSH keys:

1. Ensure the host's SSH key is in `secrets/secrets.nix`:
   ```nix
   new-host = "ssh-ed25519 AAAAC3Nza... root@new-host";
   systems = [... new-host ...];
   ```

2. Re-encrypt secrets if needed:
   ```bash
   cd secrets/
   agenix --rekey
   ```

3. Deploy with nixos-anywhere - secrets will be available on first boot

---

## Configuration Reference

### Cache Client Options

Located in `modules/nix-builder/client.nix`:

```nix
services.nix-builder.client = {
  enable = true;                    # Enable cache client

  cacheUrl = "http://nix-cache";    # Cache URL
                                    # Can be: "http://nix-cache" (Tailscale)
                                    #         "http://nas-01:5000" (direct)
                                    #         "http://192.168.5.300:5000" (IP)

  publicKey = "nas-01-cache:...";   # Binary cache signing key
                                    # Get from: secrets/cache-public-key.txt

  priority = 30;                    # Cache priority
                                    # Lower = higher priority
                                    # Default upstream cache = 40
};
```

### Build Coordinator Options

Located in `modules/nix-builder/default.nix`:

```nix
services.nix-builder.coordinator = {
  enable = true;                    # Enable build coordinator

  enableLocalBuilds = true;         # Allow local builds as fallback
                                    # If false, only use remote builders

  localCache = "http://localhost:5000";  # Local cache URL
                                         # null to disable cache population

  sshKeyPath = null;               # Path to SSH key
                                   # null = use agenix secret

  builders = [
    {
      hostname = "builder-name";    # Hostname or IP
      sshUser = "nix-builder";      # SSH user (default)
      systems = ["x86_64-linux"];   # Supported architectures
      maxJobs = 4;                  # Parallel jobs
      speedFactor = 1;              # Relative speed weight
      supportedFeatures = [         # Build capabilities
        "nixos-test"
        "benchmark"
        "big-parallel"
        "kvm"
      ];
    }
  ];
};
```

### Harmonia Cache Options

Located in `clubcotton/services/harmonia/default.nix`:

```nix
services.clubcotton.harmonia = {
  enable = true;                    # Enable Harmonia cache

  port = 5000;                      # HTTP port

  signKeyPath = null;               # Path to signing key
                                    # null = use agenix secret

  workers = 4;                      # Worker threads

  maxConnections = 25;              # Max concurrent connections

  tailnetHostname = "nix-cache";   # Tailscale hostname
                                    # null = disable Tailscale
};
```

---

## Troubleshooting

### Cache Not Accessible

**Symptom:** `curl http://nix-cache/nix-cache-info` fails

**Solutions:**
1. Check Tailscale is running: `systemctl status tailscaled`
2. Verify Tailscale hostname: `tailscale status | grep nix-cache`
3. Check Harmonia service on nas-01: `ssh nas-01 systemctl status harmonia`
4. Try direct access: `curl http://nas-01:5000/nix-cache-info`

### Builds Not Using Cache

**Symptom:** Rebuilding packages that should be cached

**Solutions:**
1. Verify cache is in substituters:
   ```bash
   nix show-config | grep substituters
   ```
2. Check signing key matches:
   ```bash
   nix show-config | grep trusted-public-keys
   ```
3. Test cache manually:
   ```bash
   curl http://nix-cache/nix-cache-info
   ```
4. Check cache has content:
   ```bash
   ssh nas-01 "ls -lh /nix/store | wc -l"
   ```

### Builder SSH Connection Fails

**Symptom:** `ssh://nix-builder@hostname` connections fail

**Solutions:**
1. Test SSH manually from nas-01:
   ```bash
   ssh nas-01
   ssh -i /run/agenix/nix-builder-ssh-key nix-builder@builder-host
   ```
2. Check builder user exists:
   ```bash
   ssh builder-host "id nix-builder"
   ```
3. Verify authorized_keys:
   ```bash
   ssh builder-host "cat /home/nix-builder/.ssh/authorized_keys"
   ```
4. Check SSH logs on builder:
   ```bash
   ssh builder-host "journalctl -u sshd -f"
   ```

### Cache Signing Issues

**Symptom:** "cannot verify signature" or "substituter is not trusted"

**Solutions:**
1. Verify public key is correct:
   ```bash
   cd secrets/
   cat cache-public-key.txt
   # Compare with client configs
   ```
2. Check signing key on nas-01:
   ```bash
   ssh nas-01 "agenix -d /run/agenix/harmonia-signing-key"
   ```
3. Re-sign store paths:
   ```bash
   ssh nas-01
   nix store sign --key-file /run/agenix/harmonia-signing-key \
     /nix/store/*-hello-*
   ```

### Builder Not Being Used

**Symptom:** Builds only happen locally, never distributed

**Solutions:**
1. Check build machines config:
   ```bash
   ssh nas-01 "nix show-config | grep builders"
   ```
2. Verify SSH connectivity (see above)
3. Check builder's nix-daemon is running:
   ```bash
   ssh builder-host "systemctl status nix-daemon"
   ```
4. Test manual remote build:
   ```bash
   ssh nas-01
   nix-build '<nixpkgs>' -A hello \
     --builders 'ssh://nix-builder@builder-host' -v
   ```

### Slow Cache Performance

**Symptom:** Cache is slow or times out

**Solutions:**
1. Check nas-01 load:
   ```bash
   ssh nas-01 "uptime"
   ssh nas-01 "iostat 1 5"
   ```
2. Increase Harmonia workers (edit `nas-01/default.nix`):
   ```nix
   services.clubcotton.harmonia.workers = 8;  # Increase from 4
   ```
3. Check network bandwidth:
   ```bash
   iftop -i tailscale0  # On nas-01
   ```
4. Check ZFS performance:
   ```bash
   ssh nas-01 "zpool iostat -v ssdpool 1 5"
   ```

---

## Monitoring and Maintenance

### Check Cache Statistics

```bash
# Cache size
ssh nas-01 "du -sh /nix/store"

# Dataset usage
ssh nas-01 "zfs list | grep nix-cache"

# Cache hits (from Harmonia logs)
ssh nas-01 "journalctl -u harmonia -n 1000 | grep -c 'GET'"
```

### Monitor Build Distribution

```bash
# View current builds
ssh nas-01 "nix-store --query --deriver \$(ls -t /nix/store/*drv | head -5)"

# Check builder availability
ssh nas-01 "nix-build '<nixpkgs>' -A hello --dry-run 2>&1 | grep builders"
```

### Garbage Collection

The cache is subject to normal garbage collection:

```bash
# On nas-01
nix-collect-garbage --delete-older-than 30d

# More aggressive (caution!)
nix-collect-garbage --delete-older-than 7d
```

To preserve cache longer, increase the ZFS quota instead.

### Update Public Key

If you regenerate secrets:

1. Run `secrets/regenerate-nix-cache-secrets.sh`
2. Update `modules/nix-builder/client.nix` with new key
3. Deploy to nas-01: `just switch nas-01`
4. Deploy to all clients: `just deploy-all` (or individually)
5. Old cached items will be ignored; rebuilds will use new key

---

## Performance Tips

### Optimize Build Settings

On builder hosts, tune for performance:

```nix
nix.settings = {
  max-jobs = 4;           # Match CPU core count
  cores = 0;              # Use all cores per job
  auto-optimise-store = true;  # Deduplicate automatically
};
```

### Prioritize Fast Builders

In nas-01's coordinator config, use `speedFactor` to prefer fast machines:

```nix
{
  hostname = "nas-01";
  speedFactor = 2;  # Fast NVMe storage, prefer this
}
{
  hostname = "slow-builder";
  speedFactor = 1;  # Normal speed
}
```

### Enable Compression

For remote builders over WAN, enable SSH compression:

```nix
programs.ssh.extraConfig = ''
  Host slow-remote-builder
    Compression yes
    CompressionLevel 6
'';
```

### Cache Prefetching

Pre-populate cache for common packages:

```bash
# On nas-01
nix-build '<nixpkgs>' -A hello firefox chromium
# These will be cached automatically
```

---

## Advanced Topics

### Multiple Cache Tiers

Add upstream caches for fallback:

```nix
services.nix-builder.client = {
  enable = true;
  cacheUrl = "http://nix-cache";
  publicKey = "nas-01-cache:...";
};

# Additional upstream caches are already included by default:
# - https://cache.nixos.org
```

Order matters: nix-cache is tried first, then cache.nixos.org.

### Cross-Architecture Builds

To build for different architectures:

1. Add QEMU support on builders:
   ```nix
   boot.binfmt.emulatedSystems = ["aarch64-linux"];
   ```

2. Update builder config:
   ```nix
   {
     hostname = "builder";
     systems = ["x86_64-linux" "aarch64-linux"];
   }
   ```

### CI/CD Integration

Use the cache in CI pipelines:

```yaml
# GitHub Actions example
- name: Configure Nix Cache
  run: |
    mkdir -p ~/.config/nix
    echo "substituters = http://nix-cache https://cache.nixos.org" >> ~/.config/nix/nix.conf
    echo "trusted-public-keys = nas-01-cache:... cache.nixos.org-1:..." >> ~/.config/nix/nix.conf
```

Note: Requires Tailscale or VPN access to nix-cache.

---

## See Also

- [ZFS Admin Guide](./ZFS_ADMIN_GUIDE.md) - Managing ZFS datasets
- [Remote Deployment](./REMOTE_DEPLOYMENT.md) - Deploying to remote hosts
- [Secrets README](../secrets/README-NIX-CACHE.md) - Managing cache secrets
- [Harmonia Documentation](https://github.com/nix-community/harmonia)
