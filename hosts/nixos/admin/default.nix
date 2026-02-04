# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  self,
  config,
  pkgs,
  unstablePkgs,
  inputs,
  hostName,
  ...
}: let
  # Get merged variables (defaults + host overrides)
  commonLib = import ../../common/lib.nix;
  variables = commonLib.getHostVariables hostName;
  keys = import ../../common/keys.nix;
in {
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
    # ../../../modules/grafana-alloy
    ../../../modules/tmate-ssh-server
    ../../../modules/code-server
  ];

  services.clubcotton = {
    code-server.enable = true;
    nut-server.enable = true;
    nut-client.enable = true;
    tailscale.enable = true;
    homepage.enable = true;
  };

  # Configure homepage dashboard with all services
  services.clubcotton.homepage = {
    tailnetDomain = "bobtail-clownfish.ts.net";

    # Hosts to monitor with Glances
    hosts = {
      nas-01 = {
        ip = "192.168.5.42";
        displayName = "NAS-01";
      };
      admin = {
        ip = "192.168.5.98";
        displayName = "Admin";
      };
      nix-01 = {
        ip = "192.168.5.210";
        displayName = "Nix-01";
      };
      dns-01 = {
        ip = "192.168.5.220";
        displayName = "DNS-01";
      };
    };

    # All services organized by category
    services = {
      # Arr Suite
      radarr = {
        name = "Radarr";
        category = "Arr";
        icon = "radarr.svg";
        href = "https://radarr.bobtail-clownfish.ts.net";
        description = "Movie collection manager";
      };
      sonarr = {
        name = "Sonarr";
        category = "Arr";
        icon = "sonarr.svg";
        href = "https://sonarr.bobtail-clownfish.ts.net";
        description = "TV series collection manager";
      };
      lidarr = {
        name = "Lidarr";
        category = "Arr";
        icon = "lidarr.svg";
        href = "https://lidarr.bobtail-clownfish.ts.net";
        description = "Music collection manager";
      };
      prowlarr = {
        name = "Prowlarr";
        category = "Arr";
        icon = "prowlarr.svg";
        href = "https://prowlarr.bobtail-clownfish.ts.net";
        description = "Indexer manager for *arr apps";
      };
      readarr-epub = {
        name = "Readarr (Books)";
        category = "Arr";
        icon = "readarr.svg";
        href = "https://readarr-epub.bobtail-clownfish.ts.net";
        description = "E-book collection manager";
      };
      readarr-audio = {
        name = "Readarr (Audio)";
        category = "Arr";
        icon = "readarr.svg";
        href = "https://readarr-audio.bobtail-clownfish.ts.net";
        description = "Audiobook collection manager";
      };
      jellyseerr = {
        name = "Jellyseerr";
        category = "Arr";
        icon = "jellyseerr.svg";
        href = "https://jellyseerr.bobtail-clownfish.ts.net";
        description = "Media request management";
      };

      # Media
      jellyfin = {
        name = "Jellyfin";
        category = "Media";
        icon = "jellyfin.svg";
        href = "https://jellyfin.bobtail-clownfish.ts.net";
        description = "Media streaming server";
      };
      navidrome = {
        name = "Navidrome";
        category = "Media";
        icon = "navidrome.svg";
        href = "https://navidrome.bobtail-clownfish.ts.net";
        description = "Music streaming server";
      };
      immich = {
        name = "Immich";
        category = "Media";
        icon = "immich.svg";
        href = "https://immich.bobtail-clownfish.ts.net";
        description = "Photo and video backup";
      };
      calibre-web = {
        name = "Calibre-Web";
        category = "Media";
        icon = "calibre-web.svg";
        href = "https://calibre-web.bobtail-clownfish.ts.net";
        description = "E-book library browser";
      };

      # Downloads
      sabnzbd = {
        name = "SABnzbd";
        category = "Downloads";
        icon = "sabnzbd.svg";
        href = "https://sabnzbd.bobtail-clownfish.ts.net";
        description = "Usenet download client";
      };
      pinchflat = {
        name = "Pinchflat";
        category = "Downloads";
        icon = "pinchflat.svg";
        href = "https://pinchflat.bobtail-clownfish.ts.net";
        description = "YouTube media archiver";
      };

      # Content
      paperless = {
        name = "Paperless-ngx";
        category = "Content";
        icon = "paperless-ngx.svg";
        href = "https://paperless.bobtail-clownfish.ts.net";
        description = "Document management system";
      };
      freshrss = {
        name = "FreshRSS";
        category = "Content";
        icon = "freshrss.svg";
        href = "https://freshrss.bobtail-clownfish.ts.net";
        description = "RSS feed aggregator";
      };
      wallabag = {
        name = "Wallabag";
        category = "Content";
        icon = "wallabag.svg";
        href = "https://wallabag.bobtail-clownfish.ts.net";
        description = "Read-it-later service";
      };
      filebrowser = {
        name = "File Browser";
        category = "Content";
        icon = "filebrowser.svg";
        href = "https://filebrowser.bobtail-clownfish.ts.net";
        description = "Web-based file manager";
      };

      # Infrastructure
      forgejo = {
        name = "Forgejo";
        category = "Infrastructure";
        icon = "forgejo.svg";
        href = "https://forgejo.bobtail-clownfish.ts.net";
        description = "Self-hosted Git forge";
      };
      atuin = {
        name = "Atuin";
        category = "Infrastructure";
        icon = "atuin.png";
        href = "https://atuin.bobtail-clownfish.ts.net";
        description = "Shell history sync server";
      };
      llm = {
        name = "Open WebUI";
        category = "Infrastructure";
        icon = "open-webui.svg";
        href = "https://llm.bobtail-clownfish.ts.net";
        description = "LLM chat interface";
      };
      harmonia = {
        name = "Harmonia";
        category = "Infrastructure";
        icon = "nix.svg";
        href = "https://nix-cache.bobtail-clownfish.ts.net";
        description = "Nix binary cache server";
      };

      # Monitoring (local to admin)
      grafana = {
        name = "Grafana";
        category = "Monitoring";
        icon = "grafana.svg";
        href = "http://admin:3000";
        description = "Metrics dashboards";
      };
      prometheus = {
        name = "Prometheus";
        category = "Monitoring";
        icon = "prometheus.svg";
        href = "http://admin:9001";
        description = "Metrics collection";
      };
    };

    # External bookmarks
    bookmarks = [
      {
        External = [
          {
            GitHub = [
              {
                abbr = "GH";
                href = "https://github.com";
                icon = "github.svg";
              }
            ];
          }
          {
            "Home Assistant" = [
              {
                abbr = "HA";
                href = "http://homeassistant.lan:8123";
                icon = "home-assistant.svg";
              }
            ];
          }
        ];
      }
    ];

    # Miscellaneous external services
    misc = [
      {
        "Home Assistant" = {
          description = "Smart home control";
          href = "http://homeassistant.lan:8123";
          icon = "home-assistant.svg";
        };
      }
      {
        UniFi = {
          description = "Network management";
          href = "https://unifi.ui.com";
          icon = "ubiquiti.svg";
        };
      }
    ];
  };

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

  services.clubcotton.tailscale.useRoutingFeatures = "server";

  services.clubcotton.code-server = {
    tailnetHostname = "admin-vscode";
    user = "bcotton";
  };

  services.vscode-server.enableFHS = true;

  environment.systemPackages = with pkgs; [
    nodejs_22
  ];

  # Set your time zone.
  time.timeZone = variables.timeZone;

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

  programs.zsh.enable = variables.zshEnable;

  users.users.root = {
    openssh.authorizedKeys.keys = keys.rootAuthorizedKeys;
  };

  # List services that you want to enable:
  services.openssh.enable = variables.opensshEnable;
  services.nfs.server.enable = true;

  # See https://xeiaso.net/blog/prometheus-grafana-loki-nixos-2020-11-20/
  # Turn on node_exporter
  services.prometheus = {
    # Exclude webdav service from blackbox monitoring
    tsnsrvExcludeList = ["webdav"];

    exporters = {
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = variables.firewallEnable;

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
  system.stateVersion = variables.stateVersion;
}
