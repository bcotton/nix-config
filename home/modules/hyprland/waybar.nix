# Waybar status bar configuration
{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.programs.hyprland-config;

  # Catppuccin Mocha colors (hardcoded for now, can integrate with stylix later)
  colors = {
    base = "1e1e2e";
    mantle = "181825";
    crust = "11111b";
    surface0 = "313244";
    surface1 = "45475a";
    surface2 = "585b70";
    text = "cdd6f4";
    subtext0 = "a6adc8";
    subtext1 = "bac2de";
    blue = "89b4fa";
    lavender = "b4befe";
    sapphire = "74c7ec";
    sky = "89dceb";
    teal = "94e2d5";
    green = "a6e3a1";
    yellow = "f9e2af";
    peach = "fab387";
    maroon = "eba0ac";
    red = "f38ba8";
    mauve = "cba6f7";
    pink = "f5c2e7";
    flamingo = "f2cdcd";
    rosewater = "f5e0dc";
  };
in {
  config = mkIf (cfg.enable && cfg.enableWaybar) {
    programs.waybar = {
      enable = true;
      systemd.enable = true;

      settings = [
        {
          layer = "top";
          position = "top";
          height = 34;
          spacing = 4;

          modules-left = [
            "hyprland/workspaces"
            "hyprland/window"
          ];

          modules-center = [
            "clock"
          ];

          modules-right = [
            "pulseaudio"
            "network"
            "cpu"
            "memory"
            "battery"
            "tray"
          ];

          "hyprland/workspaces" = {
            format = "{name}";
            on-click = "activate";
            on-scroll-up = "hyprctl dispatch workspace e+1";
            on-scroll-down = "hyprctl dispatch workspace e-1";
            all-outputs = true;
          };

          "hyprland/window" = {
            max-length = 50;
            separate-outputs = true;
          };

          "clock" = {
            format = "  {:%H:%M}";
            format-alt = "  {:%A, %B %d, %Y}";
            tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          };

          "cpu" = {
            format = "  {usage}%";
            tooltip = true;
            interval = 5;
          };

          "memory" = {
            format = "  {}%";
            interval = 5;
          };

          "battery" = {
            states = {
              warning = 30;
              critical = 15;
            };
            format = "{icon}  {capacity}%";
            format-charging = "󰂄  {capacity}%";
            format-plugged = "󰚥  {capacity}%";
            format-icons = ["󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
            tooltip-format = "{timeTo}";
          };

          "network" = {
            format-wifi = "󰖩  {signalStrength}%";
            format-ethernet = "󰈀  {ifname}";
            format-disconnected = "󰖪  Disconnected";
            tooltip-format = "{ifname}: {ipaddr}/{cidr}\n{essid}";
            on-click = "nm-connection-editor";
          };

          "pulseaudio" = {
            format = "{icon}  {volume}%";
            format-bluetooth = "󰂯  {volume}%";
            format-muted = "󰝟  Muted";
            format-icons = {
              default = ["󰕿" "󰖀" "󰕾"];
              headphone = "󰋋";
            };
            on-click = "pavucontrol";
            tooltip-format = "{desc}: {volume}%";
          };

          "tray" = {
            icon-size = 18;
            spacing = 10;
          };
        }
      ];

      style = ''
        * {
          font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free";
          font-size: 13px;
          min-height: 0;
        }

        window#waybar {
          background-color: #${colors.base};
          color: #${colors.text};
          border-bottom: 2px solid #${colors.surface0};
        }

        #workspaces {
          margin: 4px 4px;
        }

        #workspaces button {
          padding: 2px 8px;
          margin: 0 2px;
          color: #${colors.subtext0};
          background-color: transparent;
          border-radius: 6px;
          transition: all 0.2s ease;
        }

        #workspaces button:hover {
          background-color: #${colors.surface0};
          color: #${colors.text};
        }

        #workspaces button.active {
          background-color: #${colors.blue};
          color: #${colors.base};
        }

        #workspaces button.urgent {
          background-color: #${colors.red};
          color: #${colors.base};
        }

        #window {
          padding: 0 12px;
          color: #${colors.subtext1};
        }

        #clock {
          font-weight: bold;
          color: #${colors.lavender};
        }

        #cpu {
          color: #${colors.teal};
        }

        #memory {
          color: #${colors.peach};
        }

        #battery {
          color: #${colors.green};
        }

        #battery.warning {
          color: #${colors.yellow};
        }

        #battery.critical {
          color: #${colors.red};
          animation: blink 1s linear infinite;
        }

        #battery.charging {
          color: #${colors.green};
        }

        @keyframes blink {
          to {
            color: #${colors.text};
          }
        }

        #network {
          color: #${colors.sapphire};
        }

        #network.disconnected {
          color: #${colors.red};
        }

        #pulseaudio {
          color: #${colors.mauve};
        }

        #pulseaudio.muted {
          color: #${colors.surface2};
        }

        #tray {
          margin-right: 8px;
        }

        #tray > .passive {
          -gtk-icon-effect: dim;
        }

        #tray > .needs-attention {
          -gtk-icon-effect: highlight;
        }

        /* Common module styling */
        #cpu,
        #memory,
        #battery,
        #network,
        #pulseaudio,
        #clock {
          padding: 0 10px;
          margin: 4px 2px;
          background-color: #${colors.surface0};
          border-radius: 6px;
        }

        tooltip {
          background-color: #${colors.base};
          border: 1px solid #${colors.surface1};
          border-radius: 8px;
        }

        tooltip label {
          color: #${colors.text};
          padding: 4px;
        }
      '';
    };
  };
}





