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
    gnome-tweaks
    gnomeExtensions.tiling-shell
    gnomeExtensions.clipboard-history
    dconf2nix # used to make a nix expression from the dconf bin
    dconf-editor
    wl-clipboard
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

  # Pre 25.11
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  lib.hm.gvariant.dconf.settings = {
    "org/gnome/desktop/background" = {
      color-shading-type = "solid";
      picture-options = "zoom";
      picture-uri = "file:///home/tomcotton/wallpaper/toms-wallpaper.png";
      picture-uri-dark = "file:///home/tomcotton/wallpaper/toms-wallpaper.png";
      primary-color = "#000000000000";
      secondary-color = "#000000000000";
    };
    "org/gnome/desktop/interface" = {
      clock-format = "12h";
      clock-show-seconds = false;
      clock-show-weekday = true;
    };
    "org/gnome/desktop/screensaver" = {
      color-shading-type = "solid";
      picture-options = "zoom";
      picture-uri = "file:///home/tomcotton/.local/share/backgrounds/2025-09-19-22-51-51-toms-wallpaper.png";
      primary-color = "#000000000000";
      secondary-color = "#000000000000";
    };
    "org/gnome/desktop/wm/keybindings" = {
      maximize = [];
      minimize = [];
      move-to-workspace-1 = ["<Shift><Super>1"];
      move-to-workspace-2 = ["<Shift><Super>2"];
      move-to-workspace-3 = ["<Shift><Super>3"];
      move-to-workspace-4 = ["<Shift><Super>4"];
      switch-to-workspace-1 = ["<Super>1"];
      switch-to-workspace-2 = ["<Super>2"];
      switch-to-workspace-3 = ["<Super>3"];
      switch-to-workspace-4 = ["<Super>4"];
      unmaximize = [];
    };
    "org/gnome/desktop/wm/preferences" = {
      auto-raise = true;
      focus-mode = "sloppy";
    };
    "org/gnome/mutter/wayland/keybindings" = {
      restore-shortcuts = [];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "Launch7";
      command = "ghostty";
      name = "Open Ghostty";
    };
    "org/gnome/shell/app-switcher" = {
      current-workspace-only = true;
    };
    "org/gnome/shell/extensions/tilingshell" = {
      enable-autotiling = true;
      enable-span-multiple-tiles = false;
      enable-tiling-system = true;
      enable-window-border = true;
      focus-window-down = [""];
      focus-window-left = [""];
      focus-window-right = [""];
      focus-window-up = [""];
      last-version-name-installed = "16.4";
      layouts-json = "[{\"id\":\"Layout 1\",\"tiles\":[{\"x\":0,\"y\":0,\"width\":0.22,\"height\":0.5,\"groups\":[1,2]},{\"x\":0,\"y\":0.5,\"width\":0.22,\"height\":0.5,\"groups\":[1,2]},{\"x\":0.22,\"y\":0,\"width\":0.56,\"height\":1,\"groups\":[2,3]},{\"x\":0.78,\"y\":0,\"width\":0.22,\"height\":0.5,\"groups\":[3,4]},{\"x\":0.78,\"y\":0.5,\"width\":0.22,\"height\":0.5,\"groups\":[3,4]}]},{\"id\":\"Layout 2\",\"tiles\":[{\"x\":0,\"y\":0,\"width\":0.22,\"height\":1,\"groups\":[1]},{\"x\":0.22,\"y\":0,\"width\":0.56,\"height\":1,\"groups\":[1,2]},{\"x\":0.78,\"y\":0,\"width\":0.22,\"height\":1,\"groups\":[2]}]},{\"id\":\"Layout 3\",\"tiles\":[{\"x\":0,\"y\":0,\"width\":0.611328125,\"height\":1,\"groups\":[1]},{\"x\":0.611328125,\"y\":0,\"width\":0.38867187500000006,\"height\":1,\"groups\":[1]}]},{\"id\":\"Layout 4\",\"tiles\":[{\"x\":0,\"y\":0,\"width\":0.62421875,\"height\":1,\"groups\":[1]},{\"x\":0.62421875,\"y\":0,\"width\":0.37578125,\"height\":0.5809659090909091,\"groups\":[2,1]},{\"x\":0.62421875,\"y\":0.5809659090909091,\"width\":0.37578125,\"height\":0.4190340909090909,\"groups\":[2,1]}]}]";
      move-window-down = ["<Super>Down"];
      move-window-left = ["<Super>Left"];
      move-window-right = ["<Super>Right"];
      move-window-up = ["<Super>Up"];
      overridden-settings = "{\"org.gnome.mutter.keybindings\":{\"toggle-tiled-right\":\"['<Super>Right']\",\"toggle-tiled-left\":\"['<Super>Left']\"},\"org.gnome.desktop.wm.keybindings\":{\"maximize\":\"['<Super>Up']\",\"unmaximize\":\"['<Super>Down', '<Alt>F5']\"},\"org.gnome.mutter\":{\"edge-tiling\":\"true\"}}";
      selected-layouts = [["Layout 4"] ["Layout 4"] ["Layout 4"]];
      span-multiple-tiles-activation-key = ["-1"];
      tiling-system-activation-key = ["-1"];
      window-border-color = "rgb(51,209,122)";
    };
    "org/gnome/shell/keybindings" = {
      switch-to-application-1 = [];
      switch-to-application-2 = [];
      switch-to-application-3 = [];
      switch-to-application-4 = [];
    };
    "org/gtk/settings/file-chooser" = {
      clock-format = "12h";
    };
  };

  # services.xserver = {
  #     enable = true;
  #     desktopManager = {
  #       xterm.enable = false;
  #     };
  #     windowManager.i3 = {
  #       enable = true;
  #       extraPackages = with pkgs; [
  #         dmenu #application launcher most people use
  #         i3status # gives you the default i3 status bar
  #         i3blocks #if you are planning on using i3blocks over i3status
  #       ];
  #     };
  #   };

  # services.displayManager.sddm.enable = true;
  # services.desktopManager.plasma6.enable = true;

  # systemd.services.myCustomService = {
  #     description = "Launch Plasma with i3";
  #     before = [ "plasma-workspace.target" ];
  #     wantedBy = [ "plasma-workspace.target" ]; # Or other targets like "graphical.target"
  #     serviceConfig = {
  #         Type = "simple"; # Or "forking", "oneshot", etc.
  #         ExecStart = "/usr/bin/i3";
  #         Restart = "on-failure";
  #     };
  # Optional: Define dependencies or other unit options
  # after = [ "network.target" ];
  # };
}
