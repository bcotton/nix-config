# Variable System - Complete Guide

## Overview

A centralized **default + override** variable system for managing host configurations across all NixOS and Darwin hosts in this nix-config. Successfully implemented across **25 hosts** (20 NixOS + 5 Darwin).

## Quick Start

### One-Liners

```bash
# Create new host
./hosts/create-host.sh hostname nixos

# Add new variable
vim hosts/common/variables.nix

# Override for specific host
vim hosts/nixos/hostname/variables.nix
```

### Basic Usage Pattern

```nix
# In any host's default.nix
{ hostName, ... }: let
  commonLib = import ../../common/lib.nix;
  variables = commonLib.getHostVariables hostName;
in {
  time.timeZone = variables.timeZone;
  programs.zsh.enable = variables.zshEnable;
  services.openssh.enable = variables.opensshEnable;
}
```

## File Structure

```
hosts/
├── common/
│   ├── variables.nix       ← Defaults (edit to add new variables)
│   ├── lib.nix              ← Helper functions
│   └── example-module.nix   ← Usage example for shared modules
├── nixos/
│   └── hostname/
│       ├── default.nix      ← Uses commonLib.getHostVariables
│       └── variables.nix    ← Optional overrides
└── darwin/
    └── hostname/
        ├── default.nix      ← Uses commonLib.getHostVariables
        └── variables.nix    ← Optional overrides
```

## How It Works

1. **Default variables** are defined once in `hosts/common/variables.nix`
2. Each host can optionally create a `variables.nix` file with **only the values that differ**
3. The `commonLib.getHostVariables` function automatically merges defaults with overrides
4. The `hostName` is passed via `specialArgs` from the flake

**Key Insight:** If a host doesn't need any overrides, you can skip the `variables.nix` file entirely!

## Creating a New Host

### Using the Helper Script (Recommended)

```bash
./hosts/create-host.sh my-new-host nixos
# or
./hosts/create-host.sh my-mac darwin
```

### Manual Method

1. Create host directory:
   ```bash
   mkdir -p hosts/nixos/my-new-host
   ```

2. Create `default.nix`:
   ```nix
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
     ];
     
     networking.hostName = hostName;
     time.timeZone = variables.timeZone;
     programs.zsh.enable = variables.zshEnable;
     services.openssh.enable = variables.opensshEnable;
   }
   ```

3. **(Optional)** Create `variables.nix` only if you need to override defaults:
   ```nix
   {
     timeZone = "America/Los_Angeles";
     firewallEnable = true;
   }
   ```

4. Add host to `flake.nix`:
   ```nix
   nixosConfigurations = {
     my-new-host = nixosSystem "x86_64-linux" "my-new-host" ["username"];
   };
   ```

## Available Variables

See `hosts/common/variables.nix` for the complete list. Currently includes:

### Network Configuration
- `useDHCP` - Whether to use DHCP (default: false)

### System Configuration
- `timeZone` - System timezone (default: "America/Denver")
- `zshEnable` - Enable ZSH shell (default: true)

### Services
- `opensshEnable` - Enable OpenSSH server (default: true)
- `tailscaleEnable` - Enable Tailscale (default: true)
- `firewallEnable` - Enable firewall (default: false)

## Examples

### Host Using All Defaults

```nix
# hosts/nixos/server1/default.nix
{ hostName, ... }: let
  commonLib = import ../../common/lib.nix;
  variables = commonLib.getHostVariables hostName;
in {
  # No variables.nix file needed!
  # All values come from common/variables.nix
  time.timeZone = variables.timeZone;
}
```

### Host With Overrides

```nix
# hosts/nixos/server2/variables.nix
{
  timeZone = "America/New_York";
  firewallEnable = true;
}

# hosts/nixos/server2/default.nix  
{ hostName, ... }: let
  commonLib = import ../../common/lib.nix;
  variables = commonLib.getHostVariables hostName;
in {
  time.timeZone = variables.timeZone;  # Gets "America/New_York"
  networking.firewall.enable = variables.firewallEnable;  # Gets true
  services.tailscale.enable = variables.tailscaleEnable;  # Gets default: true
}
```

### Using in Shared Modules

```nix
# In any shared module
{
  config,
  pkgs,
  lib,
  hostName,
  ...
}: let
  commonLib = import ../hosts/common/lib.nix;
  variables = commonLib.getHostVariables hostName;
in {
  time.timeZone = variables.timeZone;
  services.openssh.enable = variables.opensshEnable;
}
```

See `hosts/common/example-module.nix` for a complete example.

## Adding New Variables

To add a new variable that all hosts can use:

1. Add it to `hosts/common/variables.nix` with a sensible default:
   ```nix
   {
     # ... existing variables
     backupEnable = true;
     monitoringEnable = true;
   }
   ```

2. That's it! All hosts now have access to these variables.

3. Override in specific hosts as needed:
   ```nix
   # hosts/nixos/some-host/variables.nix
   {
     backupEnable = false;  # Disable on this specific host
   }
   ```

## Implementation Status

### ✅ Complete Rollout (16 hosts)

**NixOS Hosts (12):**
- admin, condo-01, dns-01, frigate-host, imac-01, imac-02
- nas-01, natalya-01
- nix-01, nix-02, nix-03, nix-04, octoprint

**Darwin Hosts (4):**
- bobs-laptop, bobs-imac
- toms-MBP, toms-mini

All hosts now have:
- `variables.nix` - Empty override file (ready for customization)
- Updated `default.nix` - Using `commonLib.getHostVariables hostName`
