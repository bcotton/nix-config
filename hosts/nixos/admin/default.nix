# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  self,
  config,
  pkgs,
  unstablePkgs,
  inputs,
  ...
}: {
  # How to write modules to be imported here
  # https://discourse.nixos.org/t/append-to-a-list-in-multiple-imports-in-configuration-nix/4364/3
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # ./sound.nix
    ./smokeping.nix
    ../../../modules/node-exporter
    ../../../modules/homepage
    ../../../modules/prometheus
    ../../../modules/unpoller
    ../../../modules/grafana
    ../../../modules/grafana-alloy
    ../../../modules/tmate-ssh-server
    ../../../modules/code-server
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 20;
  boot.loader.systemd-boot.memtest86.enable = true;
  boot.loader.systemd-boot.netbootxyz.enable = true;

  # Use the GRUB 2 boot loader.
  # boot.loader.grub.enable = true;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  # boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  networking.hostName = "admin"; # Define your hostname.
  services.tailscale.enable = true;

  services.clubcotton.code-server = {
    enable = true;
    enableTsnsrv = true;
    tailnetHostname = "admin-vscode";
    user = "bcotton";
    tailscaleAuthKeyPath = config.age.secrets.tailscale-keys.path;
  };

  services.vscode-server.enableFHS = true;
  services.vscode-server.extraRuntimeDependencies = pkgs:
    with pkgs; [
      curl
    ];

  environment.systemPackages = with pkgs; [
    nodejs_22
  ];

  age.secrets."tailscale-keys.env" = {
    file = ../../../secrets/tailscale-keys.env;
  };

  age.secrets."tailscale-keys" = {
    file = ../../../secrets/tailscale-keys.raw;
  };

  # Set your time zone.
  time.timeZone = "America/Denver";

  services.rpcbind.enable = true; # needed for NFS
  systemd.mounts = [
    {
      type = "nfs";
      mountConfig = {
        Options = "noatime";
      };
      what = "192.168.5.7:/Multimedia/Music";
      where = "/mnt/music";
    }
  ];

  systemd.automounts = [
    {
      wantedBy = ["multi-user.target"];
      automountConfig = {
        TimeoutIdleSec = "600";
      };
      where = "/mnt/music";
    }
  ];

  # Enable the X11 windowing system.
  #  services.xserver.enable = true;
  #  services.xserver.displayManager.gdm.enable = true;
  #  services.xserver.desktopManager.gnome.enable = true;
  #  services.xserver.displayManager.gdm.autoSuspend = false;

  # Not sure this works
  # services.gnome.gnome-remote-desktop.enable = true;

  #environment.gnome.excludePackages = (with pkgs; [
  #  gnome-photos
  #  gnome-tour
  #]) ++ (with pkgs.gnome; [
  #  cheese # webcam tool
  #  gnome-music
  #  gnome-terminal
  #  gedit # text editor
  #  epiphany # web browser
  #  geary # email reader
  #  evince # document viewer
  #  gnome-characters
  #  totem # video player
  #  tali # poker game
  #  iagno # go game
  #  hitori # sudoku game
  #  atomix # puzzle game
  #]);

  # Configure keymap in X11
  #  services.xserver.xkb.layout = "us";
  #  services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Setup for docker
  virtualisation.docker.enable = true;

  age.secrets."pushover-key" = {
    file = ../../../secrets/pushover-key.age;
    owner = "alertmanager";
    group = "alertmanager";
  };
  age.secrets."pushover-token" = {
    file = ../../../secrets/pushover-token.age;
    owner = "alertmanager";
    group = "alertmanager";
  };
  age.secrets."condo-ha-token" = {
    file = ../../../secrets/condo-ha-token.age;
    owner = "prometheus";
    group = "prometheus";
  };
  age.secrets."homeassistant-token" = {
    file = ../../../secrets/homeassistant-token.age;
    owner = "prometheus";
    group = "prometheus";
  };
  age.secrets."unpoller" = {
    file = ../../../secrets/unpoller.age;
    owner = "unifi-poller";
    group = "unifi-poller";
  };
  age.secrets."grafana-cloud" = {
    file = ../../../secrets/grafana-cloud.age;
  };

  programs.zsh.enable = true;

  # List services that you want to enable:
  services.openssh.enable = true;
  services.nfs.server.enable = true;

  # See https://xeiaso.net/blog/prometheus-grafana-loki-nixos-2020-11-20/
  # Turn on node_exporter
  services.prometheus = {
    exporters = {
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  #system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "23.11"; # Did you read the comment?
}
