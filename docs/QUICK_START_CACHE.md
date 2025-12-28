# Quick Start: Using the Nix Cache

> **TL;DR:** Add 3 lines to your host config to use the cache. Takes 2 minutes.

## For NixOS Hosts

### 1. Edit your host config

File: `hosts/nixos/YOUR-HOST/default.nix`

```nix
{
  imports = [
    ./hardware-configuration.nix
    ../../../modules/nix-builder  # ← Add this line
    # ... other imports
  ];

  # ↓ Add these lines anywhere in the config
  services.nix-builder.client = {
    enable = true;
    cacheUrl = "http://nas-01:5000";
    publicKey = "nas-01-cache:iVhum2SXkIZcnOGZ7YyVefIeZNwzDKPKr3LcoKPtPAE=";
  };
}
```

### 2. Deploy

```bash
just switch YOUR-HOST
```

### 3. Verify

```bash
curl http://nas-01:5000/nix-cache-info
```

Done! Your builds will now use the cache.

---

## For Darwin/macOS Hosts

### 1. Edit your host config

File: `hosts/darwin/YOUR-HOST/default.nix`

```nix
{
  imports = [
    ../../../modules/nix-builder/client.nix  # ← Add this line
    # ... other imports
  ];

  # ↓ Add these lines
  services.nix-builder.client = {
    enable = true;
    cacheUrl = "http://nix-cache";
    publicKey = "nas-01-cache:cyADWw9Rx5sp2fYFSxOz6pJ9X/g9jY3RcNHmfr2eUEc=";
  };
}
```

### 2. Deploy

```bash
just switch YOUR-HOST
```

### 3. Verify

```bash
nix show-config | grep substituters
```

---

## For nixos-anywhere

The cache is automatically configured if your host config includes it.

```bash
# Deploy new host
nix run github:nix-community/nixos-anywhere -- \
  --flake .#hostname \
  root@target-ip

# Cache will work immediately on first boot
```

---

## Troubleshooting

### Cache not working?

```bash
# Check Tailscale
tailscale status | grep nix-cache

# Check cache directly
curl http://nix-cache/nix-cache-info

# Verify config
nix show-config | grep substituters
```

### Need to update the public key?

Get the current key:
```bash
cat secrets/cache-public-key.txt
```

Update in your host config:
```nix
publicKey = "nas-01-cache:NEW_KEY_HERE";
```

---

## What This Does

- ✅ Speeds up builds by using pre-built packages
- ✅ Reduces CPU usage and compile times
- ✅ Shares builds across all your machines
- ✅ Works over Tailscale (secure and private)

## What This Doesn't Do

- ❌ Doesn't make your host a builder (see full docs for that)
- ❌ Doesn't upload your builds (only nas-01 does that)
- ❌ Doesn't require any secrets on client hosts

---

## Full Documentation

See [BUILD_AND_CACHE.md](./BUILD_AND_CACHE.md) for:
- Adding hosts as builders
- Advanced configuration
- Performance tuning
- Troubleshooting
