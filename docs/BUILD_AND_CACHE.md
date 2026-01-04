# Nix Binary Cache and Distributed Build System

## Overview

This repository includes a comprehensive distributed build and binary cache infrastructure:

- **Nginx Caching Proxy** - Intelligently routes requests to local cache or upstream with caching
- **Harmonia Binary Cache** - Fast Rust-based cache server for locally-built packages on `nas-01`
- **Distributed Build Fleet** - SSH-based remote builders (nas-01, nix-01, nix-02, nix-03)
- **Automatic Cache Population** - Post-build hooks sign and cache all builds
- **Upstream Caching** - nginx caches packages from cache.nixos.org for faster repeat downloads
- **Tailscale Integration** - Secure access via `nix-cache` hostname

### Architecture

```
┌──────────────────────────────────────────────────────────┐
│                        nas-01                            │
│  ┌────────────────┐                                      │
│  │ nginx :80      │                                      │
│  │ Caching Proxy  │                                      │
│  └────┬───────┬───┘                                      │
│       │       │                                          │
│       │       └──────┐                                   │
│       │              │                                   │
│  ┌────▼────────┐  ┌──▼──────────────────┐               │
│  │  Harmonia   │  │   Upstream Cache    │               │
│  │   :5000     │  │  (cache.nixos.org)  │               │
│  │ Local Builds│  │   [with caching]    │               │
│  └─────────────┘  └─────────────────────┘               │
│                                                          │
│  ┌──────────────────┐                                   │
│  │ Build Coordinator├─┐                                 │
│  │  (SSH Builders)  │ │                                 │
│  └──────────────────┘ │                                 │
└────────────────────────┼──────────────────────────────────┘
                         │
                         ├─────► nix-01 (builder)
                         ├─────► nix-02 (builder)
                         └─────► nix-03 (builder)
                         │
                         │ Tailscale (nix-cache)
                         ▼
              All clients (NixOS + Darwin)
```

### How It Works

1. **Client requests package** → nginx on port 80
2. **nginx tries Harmonia first** → Fast local cache for packages we've built
3. **If not local (404)** → nginx proxies to cache.nixos.org and caches the response
4. **Subsequent requests** → nginx serves from its cache (no upstream hit)

### Module Architecture

The distributed build configuration is provided by the **nix-builder-config** flake, a separate repository that centralizes all builder and cache client settings:

- **Location:** `git+https://forgejo.bobtail-clownfish.ts.net/bcotton/nix-builder-config`
- **Flake Input:** Defined in this repository's `flake.nix`

The flake provides:

| Output | Description |
|--------|-------------|
| `nixosModules.client` | NixOS module for cache client configuration |
| `nixosModules.coordinator` | NixOS module for build coordinator (dispatches builds) |
| `darwinModules.client` | Darwin/macOS module for cache client |
| `lib.cache` | Cache URL and public key defaults |
| `lib.builders` | Default builder definitions |
| `lib.mkNixConf` | Generate nix.conf content (for Docker images) |
| `lib.mkMachinesFile` | Generate machines file (for Docker images) |
| `lib.mkSshConfig` | Generate SSH config (for Docker images) |

This separation allows the same configuration to be used by:
- NixOS hosts in this repository
- Darwin/macOS hosts
- Docker images (like the CI runner image)
- Any other Nix environment

### Cache Details

- **Client URL**: `http://nix-cache` (via Tailscale) or `http://nas-01:80` (direct)
- **Local Cache Storage**: `/ssdpool/local/nix-cache` (Harmonia - locally built packages)
- **Upstream Cache Storage**: `/ssdpool/local/nix-cache-proxy` (nginx - cached upstream packages, 100GB quota)
- **Cache Duration**: Upstream packages cached for 30 days
- **Public Key**: See `secrets/cache-public-key.txt` or extract with:
  ```bash
  cd secrets/ && cat cache-public-key.txt
  ```

### Benefits of Upstream Caching

The nginx caching proxy provides several key advantages:

1. **Reduced Bandwidth** - Packages from cache.nixos.org are downloaded once and cached locally
2. **Faster Builds** - Repeat builds of the same packages serve from local SSD instead of internet
3. **Offline Resilience** - Cached packages remain available even if cache.nixos.org is unreachable
4. **Single Endpoint** - Clients use one URL (`http://nas-01:80`) for both local and upstream packages
5. **Transparent Operation** - No client configuration changes needed beyond the single substituter URL
6. **Automatic Cache Management** - nginx handles cache eviction when space limit is reached

### Monitoring Cache Performance

Check cache hit rates and status:

```bash
# On nas-01, check nginx cache directory size
du -sh /ssdpool/local/nix-cache-proxy

# View cache hit/miss in nginx logs
ssh nas-01 journalctl -u nginx -f | grep X-Cache-Status

# Check what's cached
ssh nas-01 find /ssdpool/local/nix-cache-proxy -type f | head -20
```

---

## Adding Hosts as Cache Clients

All hosts can benefit from the cache without being builders. This speeds up builds and reduces redundant compilation.

> **Note:** The distributed builder configuration has been extracted to a separate flake: `nix-builder-config`. This flake provides reusable NixOS modules for both cache clients and build coordinators, and can be used by NixOS hosts as well as Docker images.

### NixOS Hosts

#### Automatic Configuration (Recommended)

Most NixOS hosts in this repository automatically get the cache client enabled via `flake-modules/hosts.nix`. The module is imported and enabled with default settings for all hosts.

If your host is defined in `flake-modules/hosts.nix`, it already has cache client access configured.

#### Manual Configuration

For hosts not using the standard flake-modules setup, add the module import manually:

```nix
{
  config,
  pkgs,
  lib,
  inputs,  # Note: inputs is needed for flake module access
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    inputs.nix-builder-config.nixosModules.client  # From nix-builder-config flake
    # ... other imports
  ];

  # ... rest of configuration
}
```

#### 2. Enable Cache Client

Add after your `services.clubcotton` block:

```nix
# Enable cache client to use nas-01 cache (via nginx proxy)
# Default values from the flake are usually sufficient
services.nix-builder.client = {
  enable = true;
  # These defaults are provided by the flake:
  # cacheUrl = "http://nas-01:80";
  # publicKey = "nas-01-cache:p+D+bL6JFK+kHmLm6YAZOC0zfVQspOG/R8ZDIkb8Kug=";
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
# Should show: http://nas-01:80 https://cache.nixos.org

# Test cache access
curl http://nix-cache/nix-cache-info
# or
curl http://nas-01:80/nix-cache-info
```

### Darwin/macOS Hosts

#### 1. Add Module Import

Edit your Darwin host configuration (e.g., `hosts/darwin/hostname/default.nix`):

```nix
{
  config,
  pkgs,
  lib,
  inputs,  # Note: inputs is needed for flake module access
  ...
}: {
  imports = [
    inputs.nix-builder-config.darwinModules.client  # From nix-builder-config flake
    # ... other imports
  ];

  # ... rest of configuration
}
```

#### 2. Enable Cache Client

```nix
# Enable cache client (via nginx proxy)
# Default values from the flake are usually sufficient
services.nix-builder.client = {
  enable = true;
  # These defaults are provided by the flake:
  # cacheUrl = "http://nas-01:80";
  # publicKey = "nas-01-cache:p+D+bL6JFK+kHmLm6YAZOC0zfVQspOG/R8ZDIkb8Kug=";
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

Follow the "NixOS Hosts" steps above to add the cache client module. For builders, also import the coordinator module:

```nix
imports = [
  ./hardware-configuration.nix
  inputs.nix-builder-config.nixosModules.client       # Cache client
  inputs.nix-builder-config.nixosModules.coordinator  # Build coordinator (if this host dispatches builds)
  # ... other imports
];
```

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
  sshKeyPath = config.age.secrets."nix-builder-ssh-key".path;  # Required: agenix secret
  signingKeyPath = config.age.secrets."harmonia-signing-key".path;  # Optional: for cache signing
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

> **Note:** The `sshKeyPath` is required for distributed builds to work. It should point to the SSH private key used to connect to remote builders. When using agenix, use the secret path as shown above.

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
  inputs,
  hostName,
  ...
}: let
  commonLib = import ../../common/lib.nix;
  variables = commonLib.getHostVariables hostName;
in {
  imports = [
    ./hardware-configuration.nix
    ../../../modules/node-exporter
    inputs.nix-builder-config.nixosModules.client  # Cache client from flake
  ];

  # Enable cache client (uses defaults from flake)
  services.nix-builder.client = {
    enable = true;
    # Defaults are provided by the flake:
    # cacheUrl = "http://nas-01:80";
    # publicKey = "nas-01-cache:p+D+bL6JFK+kHmLm6YAZOC0zfVQspOG/R8ZDIkb8Kug=";
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

> **Note:** These modules are provided by the `nix-builder-config` flake (located at `git+https://forgejo.bobtail-clownfish.ts.net/bcotton/nix-builder-config`). The flake is included as an input in this repository's `flake.nix`.

### Cache Client Options

Provided by `nix-builder-config.nixosModules.client` (or `darwinModules.client`):

```nix
services.nix-builder.client = {
  enable = true;                    # Enable cache client

  cacheUrl = "http://nas-01:80";    # Cache URL (default)
                                    # Can be: "http://nix-cache" (Tailscale)
                                    #         "http://nas-01:80" (direct)
                                    #         "http://192.168.5.300:80" (IP)

  publicKey = "nas-01-cache:...";   # Binary cache signing key (has default)
                                    # Get from: secrets/cache-public-key.txt

  priority = 30;                    # Cache priority
                                    # Lower = higher priority
                                    # Default upstream cache = 40
};
```

### Build Coordinator Options

Provided by `nix-builder-config.nixosModules.coordinator`:

```nix
services.nix-builder.coordinator = {
  enable = true;                    # Enable build coordinator

  sshKeyPath = "/path/to/key";      # Path to SSH private key (REQUIRED)
                                    # For agenix: config.age.secrets."nix-builder-ssh-key".path

  signingKeyPath = null;            # Path to cache signing key (optional)
                                    # For agenix: config.age.secrets."harmonia-signing-key".path
                                    # null = disable post-build signing

  enableLocalBuilds = true;         # Allow local builds as fallback
                                    # If false, only use remote builders

  localCache = "http://localhost:5000";  # Local cache URL
                                         # null to disable cache population

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
3. Check nginx proxy service on nas-01: `ssh nas-01 systemctl status nginx`
4. Check Harmonia service on nas-01: `ssh nas-01 systemctl status harmonia`
5. Try direct access: `curl http://nas-01:80/nix-cache-info`

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
2. Update the public key in the `nix-builder-config` flake (`lib/cache.nix`)
3. Update `flake.lock` in this repo: `nix flake update nix-builder-config`
4. Deploy to nas-01: `just switch nas-01`
5. Deploy to all clients: `just deploy-all` (or individually)
6. Old cached items will be ignored; rebuilds will use new key

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
