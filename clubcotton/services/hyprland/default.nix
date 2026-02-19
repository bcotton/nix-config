{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.clubcotton.hyprland;
in {
  options.services.clubcotton.hyprland = {
    enable = mkEnableOption "Hyprland Wayland compositor";

    enableGDM = mkOption {
      type = types.bool;
      default = true;
      description = "Enable GDM as the display manager";
    };
  };

  config = mkIf cfg.enable {
    # Enable Hyprland compositor
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    # Display manager - GDM with Wayland
    services.xserver.enable = mkIf cfg.enableGDM true;
    services.displayManager.gdm = mkIf cfg.enableGDM {
      enable = true;
      wayland = true;
    };

    # XDG Portal for Wayland - required for screen sharing, file dialogs, etc.
    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-hyprland
        pkgs.xdg-desktop-portal-gtk
      ];
    };

    # Essential system packages for Hyprland
    environment.systemPackages = with pkgs; [
      # Wayland essentials
      wl-clipboard # Clipboard support
      xdg-utils # xdg-open and friends

      # Authentication agent (for GUI privilege escalation)
      polkit_gnome

      # Basic utilities
      brightnessctl # Brightness control
      playerctl # Media player control
      pamixer # PulseAudio/PipeWire mixer
    ];

    # Enable polkit for authentication dialogs
    security.polkit.enable = true;

    # PipeWire for audio (recommended for Wayland)
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # Enable dconf for GTK apps settings persistence
    programs.dconf.enable = true;
  };
}
