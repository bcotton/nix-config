# Per-Host User Configuration

This directory contains host-specific user configuration overrides for the `bcotton` user.

## Purpose

Different hosts may require different configurations (e.g., VMs vs physical machines, different monitor setups, etc.). Instead of cluttering the main `home/bcotton.nix` with conditionals, we create separate files for each host that needs custom settings.

## Usage

1. **Create a new host config**: Create a file named `<hostname>.nix` in this directory
2. **Override settings**: Add only the settings that differ from the defaults in `home/bcotton.nix`
3. **Automatic loading**: The file is automatically imported if it exists when building for that host

## Example

For a host named `admin`, create `home/bcotton-hosts/admin.nix`:

```nix
{
  config,
  pkgs,
  lib,
  ...
}: {
  # Override Hyprland settings for admin host
  programs.hyprland-config = {
    enable = true;
    modifier = "SUPER";
    terminal = "ghostty";
    monitors = [
      "DP-1,2560x1440@144,0x0,1"
    ];
  };
  
  # Can also override other home-manager settings if needed
  # programs.git.userEmail = "admin@example.com";
}
```

## Current Configurations

- **nixos-utm**: UTM VM configuration with foot terminal, ALT modifier, and VM-optimized display settings

## Notes

- Files are imported conditionally using `lib.optional` in `home/bcotton.nix`
- If no host-specific file exists, defaults from `home/bcotton.nix` are used
- This pattern can be extended to any home-manager configuration, not just Hyprland
- Use `hostName` parameter to access the current hostname in your config

