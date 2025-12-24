# Host-specific Hyprland configuration for nixos-utm (UTM VM)
#
# This file overrides Hyprland settings in home/bcotton.nix specifically
# for the nixos-utm host. Only include settings that differ from defaults.
{
  config,
  pkgs,
  lib,
  ...
}: {
  # Hyprland configuration optimized for UTM VM
  programs.hyprland-config = {
    enable = true;

    # Use ALT as modifier (useful in VMs to avoid conflicts with host)
    modifier = "ALT";

    # Use foot terminal (CPU-rendered, works better in VMs)
    terminal = "foot";

    # Browser
    browser = "firefox";

    # Set resolution for UTM VM - Virtual-1 is the QEMU/UTM monitor
    monitors = [
      "Virtual-1,1920x1440@60,0x0,1"
    ];

    # Adjust gaps for VM usage
    gapsIn = 5;
    gapsOut = 10;
  };
}
