{
  pkgs,
  unstablePkgs,
  lib,
  inputs,
  ...
}: let
  inherit (inputs) nixpkgs nixpkgs-unstable;
in {
  environment.systemPackages = with pkgs; [
    # ---------------------------------------
    # hyprland Packages
    # ---------------------------------------
    # Desktop Environment & Window Management
    copyq
    dunst
    grim
    hyprcursor
    hypridle
    hyprlock
    hyprpaper
    hyprsunset
    mako
    rofi-wayland
    slurp
    swappy
    swaybg
    swayosd
    wf-recorder
    wlroots
    wofi
    xdg-desktop-portal-gtk
    xdg-desktop-portal-hyprland
    xdg-utils

    # System Utilities
    blueman
    brightnessctl
    cliphist
    kdePackages.kwallet
    kdePackages.kwallet-pam
    kdePackages.polkit-kde-agent-1
    networkmanagerapplet
    pavucontrol
    playerctl
    qt6.qtbase
    qt6.qtwayland
    qt6ct
    wl-clipboard

    # Desktop Applications
    blanket # Background sounds
    celluloid # Video player
    dialect # Translation app
    drawing # Drawing app
    eog # Image viewer
    evince # Document viewer
    file-roller # Archive manager
    foliate # Ebook reader
    fragments # Torrent client
    gnome-calculator
    gnome-calendar
    kdePackages.kate
    metadata-cleaner # Metadata cleaner

    # Fonts & Theming
    adwaita-qt
    adwaita-qt6
    bibata-cursors
    rose-pine-hyprcursor
    tokyo-night-gtk
  ];
  fonts.packages = with pkgs; [
    font-awesome
    font-awesome_5
    nerd-fonts.fira-code # Popular monospace font with good symbol support
    nerd-fonts.jetbrains-mono # Clear monospace font with excellent readability
    nerd-fonts.noto # Clean sans-serif font with extensive unicode support
    nerd-fonts.roboto-mono # Google's monospace font with added symbols
    nerd-fonts.ubuntu-mono # Ubuntu's monospace font with added symbols
    papirus-icon-theme
  ];

  # services.dunst.enable = true;

  programs.hyprland.enable = true;
  programs.hyprland.xwayland.enable = true;
  programs.waybar.enable = true;

  services.xserver.displayManager.gdm = {
    enable = true;
    wayland = true;
  };

  security = {
    rtkit.enable = true;
    polkit.enable = true;
  };
}
