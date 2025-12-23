# Keybindings menu - display all Hyprland keybindings in rofi
# Inspired by omarchy's keybindings menu
{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.programs.hyprland-config;

  # Script to display keybindings via rofi
  keybindingsMenuScript = pkgs.writeShellScriptBin "hypr-keybindings-menu" ''
    #!/usr/bin/env bash
    # Display Hyprland keybindings in a searchable rofi menu
    #
    # Uses hyprctl to fetch bindings and their descriptions.
    # The 'bindd' directive in hyprland config provides descriptions.

    set -euo pipefail

    # Map modifier mask values to human-readable names
    # Hyprland uses a bitmask: SHIFT=1, CTRL=4, ALT=8, SUPER=64
    map_modifiers() {
      local modmask="$1"
      local mods=""

      # SUPER (64)
      if (( modmask & 64 )); then
        mods+="SUPER "
      fi
      # CTRL (4)
      if (( modmask & 4 )); then
        mods+="CTRL "
      fi
      # ALT (8)
      if (( modmask & 8 )); then
        mods+="ALT "
      fi
      # SHIFT (1)
      if (( modmask & 1 )); then
        mods+="SHIFT "
      fi

      # Trim trailing space
      echo "''${mods% }"
    }

    # Fetch and format keybindings from hyprctl
    format_bindings() {
      ${pkgs.hyprland}/bin/hyprctl -j binds | ${pkgs.jq}/bin/jq -r '
        .[] |
        select(.description != "" and .description != null) |
        "\(.modmask)|\(.key)|\(.description)"
      ' | while IFS='|' read -r modmask key description; do
        # Convert modmask to readable format
        mods=$(map_modifiers "$modmask")

        # Format the key combination
        if [[ -n "$mods" ]]; then
          combo="$mods + $key"
        else
          combo="$key"
        fi

        # Output in aligned format for rofi
        printf "%-30s  →  %s\n" "$combo" "$description"
      done | sort -t'→' -k2
    }

    # Display in rofi
    format_bindings | ${pkgs.rofi-wayland}/bin/rofi -dmenu \
      -p "⌨ Keybindings" \
      -i \
      -no-custom \
      -theme-str 'window { width: 700px; }' \
      -theme-str 'listview { lines: 15; }' \
      -theme-str 'element-text { font: "JetBrainsMono Nerd Font 11"; }'
  '';
in {
  config = mkIf (cfg.enable && cfg.enableKeybindingsMenu) {
    # Add the keybindings menu script to the user's packages
    home.packages = [keybindingsMenuScript];

    # Note: The keybinding itself is added in default.nix to keep all bindings together
  };
}
