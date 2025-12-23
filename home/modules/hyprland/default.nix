# Hyprland home-manager module
# Phase 1: Minimal working configuration
# Phase 2: Rofi launcher and Waybar status bar
#
# This module provides per-user Hyprland configuration with sensible defaults.
# Users can override options in their home/<username>.nix file.
{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.programs.hyprland-config;
in {
  imports = [
    ./rofi.nix
    ./waybar.nix
    ./keybindings-menu.nix
  ];

  options.programs.hyprland-config = {
    enable = mkEnableOption "Hyprland user configuration";

    # === Launcher & Bar ===
    enableRofi = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Rofi application launcher";
    };

    enableWaybar = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Waybar status bar";
    };

    enableKeybindingsMenu = mkOption {
      type = types.bool;
      default = true;
      description = "Enable keybindings menu (shows all shortcuts in rofi)";
    };

    terminal = mkOption {
      type = types.str;
      default = "foot";
      description = "Default terminal emulator command (use 'foot' for VMs, 'ghostty' for native)";
    };

    browser = mkOption {
      type = types.str;
      default = "firefox";
      description = "Default web browser command";
    };

    modifier = mkOption {
      type = types.str;
      default = "SUPER";
      description = "Main modifier key (SUPER, ALT, CTRL)";
    };

    # Monitor configuration
    monitors = mkOption {
      type = types.listOf types.str;
      default = [
        ",preferred,auto,auto" # Auto-detect and configure monitors
      ];
      description = ''
        List of monitor configurations in Hyprland format.
        Format: "name,resolution,position,scale"
        Example: ["DP-1,1920x1080@60,0x0,1" "HDMI-A-1,1920x1080@60,1920x0,1"]
      '';
    };

    # Gaps and borders
    gapsIn = mkOption {
      type = types.int;
      default = 5;
      description = "Gaps between windows";
    };

    gapsOut = mkOption {
      type = types.int;
      default = 10;
      description = "Gaps between windows and screen edges";
    };

    borderSize = mkOption {
      type = types.int;
      default = 2;
      description = "Window border size in pixels";
    };

    # Colors (can be overridden for theming)
    activeBorderColor = mkOption {
      type = types.str;
      default = "rgb(89b4fa)"; # Catppuccin blue
      description = "Active window border color";
    };

    inactiveBorderColor = mkOption {
      type = types.str;
      default = "rgb(313244)"; # Catppuccin surface0
      description = "Inactive window border color";
    };

    # Extra settings to merge into hyprland config
    extraSettings = mkOption {
      type = types.attrs;
      default = {};
      description = "Extra settings to merge into wayland.windowManager.hyprland.settings";
    };

    # Extra config lines (raw hyprland.conf syntax)
    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Extra configuration lines in raw Hyprland config format";
    };
  };

  config = mkIf cfg.enable {
    # Reload Hyprland config after home-manager activation
    # Only runs if Hyprland is currently active (HYPRLAND_INSTANCE_SIGNATURE is set)
    home.activation.reloadHyprland = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        ${pkgs.hyprland}/bin/hyprctl reload || true
      fi
    '';

    # Essential user packages for Hyprland session
    home.packages = with pkgs; [
      # Terminal - include foot as fallback for VMs where GPU-accelerated
      # terminals like ghostty may not work
      foot

      # Clipboard
      wl-clipboard
      cliphist

      # Screenshot (basic)
      grim
      slurp

      # Notification daemon
      libnotify

      # Fonts (for waybar icons)
      nerd-fonts.jetbrains-mono
      font-awesome

      # Audio control GUI
      pavucontrol

      # Network manager GUI
      networkmanagerapplet
    ];

    # Hyprland configuration via home-manager
    wayland.windowManager.hyprland = {
      enable = true;

      systemd = {
        enable = true;
        enableXdgAutostart = true;
        variables = ["--all"];
      };

      xwayland.enable = true;

      settings = mkMerge [
        {
          # Monitor configuration
          monitor = cfg.monitors;

          # Input configuration
          input = {
            kb_layout = "us";
            kb_options = "caps:super"; # Caps Lock as Super
            numlock_by_default = true;
            follow_mouse = 1;
            sensitivity = 0;

            touchpad = {
              natural_scroll = true;
              disable_while_typing = true;
            };
          };

          # General settings
          general = {
            "$modifier" = cfg.modifier;
            layout = "dwindle";
            gaps_in = cfg.gapsIn;
            gaps_out = cfg.gapsOut;
            border_size = cfg.borderSize;
            resize_on_border = true;
            "col.active_border" = cfg.activeBorderColor;
            "col.inactive_border" = cfg.inactiveBorderColor;
          };

          # Decoration
          decoration = {
            rounding = 8;
            blur = {
              enabled = true;
              size = 5;
              passes = 2;
              new_optimizations = true;
            };
            shadow = {
              enabled = true;
              range = 4;
              render_power = 3;
            };
          };

          # Animations - minimal for now
          animations = {
            enabled = true;
            bezier = [
              "ease, 0.25, 0.1, 0.25, 1"
            ];
            animation = [
              "windows, 1, 3, ease"
              "windowsOut, 1, 3, ease"
              "fade, 1, 3, ease"
              "workspaces, 1, 3, ease"
            ];
          };

          # Dwindle layout
          dwindle = {
            pseudotile = true;
            preserve_split = true;
            force_split = 2;
          };

          # Misc settings
          misc = {
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
            mouse_move_enables_dpms = true;
            key_press_enables_dpms = true;
            vfr = true;
          };

          # Cursor
          cursor = {
            no_hardware_cursors = true;
          };

          # Environment variables for Wayland compatibility
          env = [
            "NIXOS_OZONE_WL,1"
            "XDG_CURRENT_DESKTOP,Hyprland"
            "XDG_SESSION_TYPE,wayland"
            "XDG_SESSION_DESKTOP,Hyprland"
            "GDK_BACKEND,wayland,x11"
            "QT_QPA_PLATFORM,wayland;xcb"
            "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
            "QT_AUTO_SCREEN_SCALE_FACTOR,1"
            "MOZ_ENABLE_WAYLAND,1"
            "ELECTRON_OZONE_PLATFORM_HINT,wayland"
          ];

          # Startup applications
          exec-once = [
            # Clipboard history
            "wl-paste --type text --watch cliphist store"
            "wl-paste --type image --watch cliphist store"
            # Polkit agent for authentication dialogs
            "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
            # Start the configured terminal
            "${cfg.terminal}"
          ];

          # ============= KEYBINDINGS =============
          # Using bindd for descriptions (shown in hyprctl binds)
          bindd = [
            # ===== Essential =====
            "${cfg.modifier}, Return, Terminal, exec, ${cfg.terminal}"
            "${cfg.modifier}, Enter, Terminal, exec, ${cfg.terminal}"
            "${cfg.modifier}, Q, Kill active window, killactive,"
            "${cfg.modifier} SHIFT, E, Exit Hyprland, exit,"

            # ===== Application Launcher (Rofi) =====
            "${cfg.modifier}, D, App launcher, exec, rofi -show drun"
            "${cfg.modifier} SHIFT, Return, App launcher, exec, rofi -show drun"
            "${cfg.modifier}, R, Run command, exec, rofi -show run"
            "${cfg.modifier}, W, Browser, exec, ${cfg.browser}"

            # ===== Window Focus (VI style) =====
            "${cfg.modifier}, H, Focus left, movefocus, l"
            "${cfg.modifier}, L, Focus right, movefocus, r"
            "${cfg.modifier}, K, Focus up, movefocus, u"
            "${cfg.modifier}, J, Focus down, movefocus, d"

            # ===== Window Focus (Arrow keys) =====
            "${cfg.modifier}, Left, Focus left, movefocus, l"
            "${cfg.modifier}, Right, Focus right, movefocus, r"
            "${cfg.modifier}, Up, Focus up, movefocus, u"
            "${cfg.modifier}, Down, Focus down, movefocus, d"

            # ===== Window Movement (VI style) =====
            "${cfg.modifier} SHIFT, H, Move window left, movewindow, l"
            "${cfg.modifier} SHIFT, L, Move window right, movewindow, r"
            "${cfg.modifier} SHIFT, K, Move window up, movewindow, u"
            "${cfg.modifier} SHIFT, J, Move window down, movewindow, d"

            # ===== Window State =====
            "${cfg.modifier}, F, Fullscreen, fullscreen,"
            "${cfg.modifier} SHIFT, F, Toggle floating, togglefloating,"
            "${cfg.modifier}, P, Pseudo tile, pseudo,"
            "${cfg.modifier} SHIFT, P, Toggle split, togglesplit,"

            # ===== Workspaces 1-10 =====
            "${cfg.modifier}, 1, Workspace 1, workspace, 1"
            "${cfg.modifier}, 2, Workspace 2, workspace, 2"
            "${cfg.modifier}, 3, Workspace 3, workspace, 3"
            "${cfg.modifier}, 4, Workspace 4, workspace, 4"
            "${cfg.modifier}, 5, Workspace 5, workspace, 5"
            "${cfg.modifier}, 6, Workspace 6, workspace, 6"
            "${cfg.modifier}, 7, Workspace 7, workspace, 7"
            "${cfg.modifier}, 8, Workspace 8, workspace, 8"
            "${cfg.modifier}, 9, Workspace 9, workspace, 9"
            "${cfg.modifier}, 0, Workspace 10, workspace, 10"

            # ===== Move to Workspace =====
            "${cfg.modifier} SHIFT, 1, Move to workspace 1, movetoworkspace, 1"
            "${cfg.modifier} SHIFT, 2, Move to workspace 2, movetoworkspace, 2"
            "${cfg.modifier} SHIFT, 3, Move to workspace 3, movetoworkspace, 3"
            "${cfg.modifier} SHIFT, 4, Move to workspace 4, movetoworkspace, 4"
            "${cfg.modifier} SHIFT, 5, Move to workspace 5, movetoworkspace, 5"
            "${cfg.modifier} SHIFT, 6, Move to workspace 6, movetoworkspace, 6"
            "${cfg.modifier} SHIFT, 7, Move to workspace 7, movetoworkspace, 7"
            "${cfg.modifier} SHIFT, 8, Move to workspace 8, movetoworkspace, 8"
            "${cfg.modifier} SHIFT, 9, Move to workspace 9, movetoworkspace, 9"
            "${cfg.modifier} SHIFT, 0, Move to workspace 10, movetoworkspace, 10"

            # ===== Workspace Navigation =====
            "${cfg.modifier} CTRL, Right, Next workspace, workspace, e+1"
            "${cfg.modifier} CTRL, Left, Previous workspace, workspace, e-1"

            # ===== Special Workspace (Scratchpad) =====
            "${cfg.modifier}, Space, Toggle scratchpad, togglespecialworkspace"
            "${cfg.modifier} SHIFT, Space, Move to scratchpad, movetoworkspace, special"

            # ===== Media Keys =====
            ", XF86AudioRaiseVolume, Volume up, exec, pamixer -i 5"
            ", XF86AudioLowerVolume, Volume down, exec, pamixer -d 5"
            ", XF86AudioMute, Mute toggle, exec, pamixer -t"
            ", XF86AudioPlay, Play/Pause, exec, playerctl play-pause"
            ", XF86AudioNext, Next track, exec, playerctl next"
            ", XF86AudioPrev, Previous track, exec, playerctl previous"
            ", XF86MonBrightnessUp, Brightness up, exec, brightnessctl set +5%"
            ", XF86MonBrightnessDown, Brightness down, exec, brightnessctl set 5%-"

            # ===== Screenshot =====
            ", Print, Screenshot region, exec, grim -g \"$(slurp)\" - | wl-copy"
            "SHIFT, Print, Screenshot screen, exec, grim - | wl-copy"

            # ===== Reload Config =====
            "${cfg.modifier} SHIFT, R, Reload Hyprland config, exec, hyprctl reload"

            # ===== Help =====
            "SUPER, K, Show keybindings, exec, hypr-keybindings-menu"

            # ===== Clipboard =====
            "${cfg.modifier}, V, Clipboard history, exec, cliphist list | ${pkgs.fuzzel}/bin/fuzzel -d | cliphist decode | wl-copy"
          ];

          # Mouse bindings
          bindm = [
            "${cfg.modifier}, mouse:272, movewindow"
            "${cfg.modifier}, mouse:273, resizewindow"
          ];

          # Basic window rules
          windowrule = [
            "float, title:^(Picture-in-Picture)$"
            "pin, title:^(Picture-in-Picture)$"
            "float, class:^(pavucontrol)$"
            "float, class:^(nm-connection-editor)$"
            "float, class:^(blueman-manager)$"
          ];
        }

        # Merge user's extra settings
        cfg.extraSettings
      ];

      extraConfig = cfg.extraConfig;
    };
  };
}
