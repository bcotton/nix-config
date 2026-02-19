# Rofi application launcher configuration
{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.programs.hyprland-config;
in {
  config = mkIf (cfg.enable && cfg.enableRofi) {
    programs.rofi = {
      enable = true;
      package = pkgs.rofi;

      extraConfig = {
        modi = "drun,run,filebrowser";
        show-icons = true;
        icon-theme = "Papirus";
        font = "JetBrainsMono Nerd Font 12";
        drun-display-format = "{icon} {name}";
        display-drun = "  Apps";
        display-run = "  Run";
        display-filebrowser = "  Files";
        terminal = cfg.terminal;
      };

      theme = let
        inherit (config.lib.formats.rasi) mkLiteral;
        # Catppuccin Mocha colors (can be overridden later with stylix)
        colors = {
          base = "#1e1e2e";
          mantle = "#181825";
          surface0 = "#313244";
          surface1 = "#45475a";
          text = "#cdd6f4";
          subtext0 = "#a6adc8";
          blue = "#89b4fa";
          lavender = "#b4befe";
          sapphire = "#74c7ec";
          green = "#a6e3a1";
          peach = "#fab387";
          red = "#f38ba8";
        };
      in {
        "*" = {
          background-color = mkLiteral "transparent";
          text-color = mkLiteral colors.text;
          margin = 0;
          padding = 0;
          spacing = 0;
        };

        "window" = {
          background-color = mkLiteral colors.base;
          border = mkLiteral "2px solid";
          border-color = mkLiteral colors.lavender;
          border-radius = mkLiteral "12px";
          width = mkLiteral "600px";
          location = mkLiteral "center";
          anchor = mkLiteral "center";
        };

        "mainbox" = {
          padding = mkLiteral "12px";
          spacing = mkLiteral "12px";
        };

        "inputbar" = {
          background-color = mkLiteral colors.surface0;
          border-radius = mkLiteral "8px";
          padding = mkLiteral "12px";
          spacing = mkLiteral "8px";
          children = map mkLiteral ["prompt" "entry"];
        };

        "prompt" = {
          text-color = mkLiteral colors.blue;
        };

        "entry" = {
          placeholder = "Search...";
          placeholder-color = mkLiteral colors.subtext0;
        };

        "listview" = {
          lines = 8;
          columns = 1;
          fixed-height = true;
          spacing = mkLiteral "4px";
        };

        "element" = {
          padding = mkLiteral "8px 12px";
          border-radius = mkLiteral "8px";
          spacing = mkLiteral "12px";
        };

        "element selected" = {
          background-color = mkLiteral colors.surface1;
        };

        "element-icon" = {
          size = mkLiteral "24px";
          vertical-align = mkLiteral "0.5";
        };

        "element-text" = {
          vertical-align = mkLiteral "0.5";
        };

        "element-text selected" = {
          text-color = mkLiteral colors.lavender;
        };

        "message" = {
          background-color = mkLiteral colors.surface0;
          border-radius = mkLiteral "8px";
          padding = mkLiteral "12px";
        };

        "mode-switcher" = {
          spacing = mkLiteral "8px";
        };

        "button" = {
          padding = mkLiteral "8px 16px";
          border-radius = mkLiteral "8px";
          background-color = mkLiteral colors.surface0;
        };

        "button selected" = {
          background-color = mkLiteral colors.blue;
          text-color = mkLiteral colors.base;
        };
      };
    };
  };
}
