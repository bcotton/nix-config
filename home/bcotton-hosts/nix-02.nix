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
    enableVNC = true; # Start wayvnc service

    # Use ALT as modifier (useful in VMs to avoid conflicts with host)
    modifier = "ALT";

    # Use foot terminal (CPU-rendered, works better in VMs)
    terminal = "ghostty";

    # Browser
    browser = "firefox";

    monitors = [
      "HDMI-A-1,5120x2160@30,auto,1"
    ];

    # Adjust gaps for VM usage
    gapsIn = 5;
    gapsOut = 10;
  };
}
