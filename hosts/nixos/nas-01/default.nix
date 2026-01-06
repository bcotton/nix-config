# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  config,
  pkgs,
  lib,
  unstablePkgs,
  inputs,
  hostName,
  ...
}: let
  # Get merged variables (defaults + host overrides)
  commonLib = import ../../common/lib.nix;
  variables = commonLib.getHostVariables hostName;
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../../modules/node-exporter
    inputs.nix-builder-config.nixosModules.coordinator
    ../../../modules/samba
    ../../../modules/prometheus/nix-build-cache-check.nix
    ../../../modules/systemd-network
    ../../../users/cheryl.nix
    ./borgmatic.nix
    # Use unstable cups-pdf module TODO remove this once nixos-25.11 is released
    "${inputs.nixpkgs-unstable}/nixos/modules/services/printing/cups-pdf.nix"
  ];

  # Use unstable cups-pdf module to avoid evaluation issues
  # Use unstable cups-pdf module TODO remove this once nixos-25.11 is released
  disabledModules = ["services/printing/cups-pdf.nix"];

  services.clubcotton = {
    atuin.enable = true;
    calibre.enable = true;
    calibre-web.enable = true;
    filebrowser.enable = true;
    freshrss.enable = true;
    forgejo.enable = true;
    harmonia.enable = true;
    immich.enable = true;
    jellyfin.enable = true;
    jellyseerr.enable = true;
    kavita.enable = false;
    lidarr.enable = true;
    navidrome.enable = true;
    nix-cache-proxy.enable = true;
    nut-client.enable = true;
    open-webui.enable = true;
    paperless.enable = true;
    pinchflat.enable = true;
    postgresql.enable = true;
    prowlarr.enable = true;
    radarr.enable = true;
    readarr.enable = true;
    roon-server.enable = false;
    sabnzbd.enable = true;
    scanner.enable = true;
    sonarr.enable = true;
    syncoid.enable = true;
    tailscale.enable = true;
    wallabag.enable = true;
    webdav.enable = true;
  };

  environment.systemPackages = with pkgs; [
    beets-unstable
  ];

  services.clubcotton.harmonia = {
    bindAddress = "0.0.0.0";
  };

  # Configure distributed build fleet
  services.nix-builder.coordinator = {
    enable = true;
    sshKeyPath = config.age.secrets."nix-builder-ssh-key".path;
    signingKeyPath = config.age.secrets."harmonia-signing-key".path;
    enableLocalBuilds = true; # nas-01 builds locally, no SSH to itself
    builders = [
      # Note: localhost removed to avoid SSH loop - enableLocalBuilds handles local builds
      # Use .lan suffix for local DNS resolution (Tailscale names won't resolve from builder environment)
      {
        hostname = "nix-01.lan";
        systems = ["x86_64-linux"];
        maxJobs = 16;
        speedFactor = 1;
        supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      }
      {
        hostname = "nix-02.lan";
        systems = ["x86_64-linux"];
        maxJobs = 16;
        speedFactor = 1;
        supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      }
      {
        hostname = "nix-03.lan";
        systems = ["x86_64-linux"];
        maxJobs = 16;
        speedFactor = 1;
        supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      }
    ];
  };

  # Create builder user for remote/local builds
  users.users.nix-builder = {
    isNormalUser = true;
    description = "Nix remote builder";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDqGI8tMC4OzuZB8mmYnPSQgIgZaDUglqdIqS9U4H5fT nix-builder@nas-01"
    ];
  };

  nix.extraOptions = ''
    trusted-users = root bcotton nix-builder
  '';

  networking = {
    hostName = "nas-01";
  };

  # Configure systemd-networkd with VLANs (single NIC mode)
  clubcotton.systemd-network = {
    enable = true;
    mode = "single-nic";
    interfaces = ["enp0s31f6"];
    bridgeName = "br0";
    enableIncusBridge = false; # nas-01 doesn't run Incus, but needs VLAN access
    enableVlans = true;
    nativeVlan = {
      id = 5;
      address = "192.168.5.300/24";
      gateway = "192.168.5.1";
      dns = ["192.168.5.220"];
    };
  };

  services.nfs.server = {
    enable = true;
  };
  services.rpcbind.enable = true;

  # Set your time zone.
  time.timeZone = variables.timeZone;

  services.clubcotton.pinchflat = {
    mediaDir = "/media/youtube/pinchflat";
  };

  services.clubcotton.readarr = {
    epub = {
      dataDir = "/var/lib/readarr-epub";
      tailnetHostname = "readarr-epub";
      port = 8787;
    };
    audio = {
      dataDir = "/var/lib/readarr-audio";
      tailnetHostname = "readarr-audio";
      port = 8788;
    };
  };

  systemd.services.webdav.serviceConfig = {
    StateDirectory = "webdav";
    EnvironmentFile = config.age.secrets.webdav.path;
  };

  services.clubcotton.postgresql = {
    dataDir = "/db/postgresql/16";
    immich = {
      enable = true;
      passwordFile = config.age.secrets."immich-database".path;
    };
    open-webui = {
      enable = true;
      passwordFile = config.age.secrets."open-webui-database".path;
    };
    atuin = {
      enable = true;
      passwordFile = config.age.secrets."atuin-database".path;
    };
    forgejo = {
      enable = true;
      passwordFile = config.age.secrets."forgejo-database".path;
    };
    freshrss = {
      enable = true;
      passwordFile = config.age.secrets."freshrss-database".path;
    };
    paperless = {
      enable = true;
      passwordFile = config.age.secrets."paperless-database".path;
    };
    tfstate = {
      enable = true;
      passwordFile = config.age.secrets."tfstate-database".path;
    };
  };

  services.clubcotton.filebrowser = {
    filesDir = "/var/lib/filebrowser/files"; # Change this to somewhere on the media pool. Maybe /media/shared-files/filebrowser or something?
  };

  services.clubcotton.freshrss = {
    port = 8104;
    passwordFile = config.age.secrets."freshrss".path;
    authType = "form";
    extensions = with pkgs.freshrss-extensions; [youtube];
    tailnetHostname = "freshrss";
  };

  services.clubcotton.paperless = {
    mediaDir = "/media/documents/paperless";
    configDir = "/var/lib/paperless";
    consumptionDir = "/var/lib/paperless/consume";
    passwordFile = config.age.secrets."paperless".path;
    environmentFile = config.age.secrets."paperless-database-raw".path;
    database.createLocally = false;
    tailnetHostname = "paperless";
  };

  services.clubcotton.immich = {
    serverConfig.mediaLocation = "/media/photos/immich";
    serverConfig.logLevel = "log";
    secretsFile = config.age.secrets.immich.path;
    database = {
      enable = false;
      createDB = false;
      name = "immich";
      host = "nas-01";
    };
  };

  services.clubcotton.open-webui = {
    package = unstablePkgs.open-webui.overridePythonAttrs (oldAttrs: {
      dependencies =
        (oldAttrs.dependencies or [])
        ++ [
          unstablePkgs.python313Packages.psycopg2-binary
        ];
    });

    tailnetHostname = "llm";
    environment = {
      WEBUI_AUTH = "True";
      ENABLE_OLLAMA_API = "True";
      OLLAMA_BASE_URL = "http://toms-mini:11434";
      OLLAMA_API_BASE_URL = "http://toms-mini:11434";
    };
    environmentFile = config.age.secrets.open-webui.path;
  };

  services.clubcotton.navidrome = {
    musicFolder = "/media/music/curated";
    musicFolderRoot = "/media/music";
  };

  services.clubcotton.webdav = {
    users = {
      obsidian-sync = {
        password = "{env}OBSIDIAN_SYNC_PASSWORD";
        directory = "/media/webdav/obsidian-sync";
        permissions = "CRUD";
      };
      zotero-sync = {
        password = "{env}ZOTERO_SYNC_PASSWORD";
        directory = "/media/webdav/zotero-sync";
        permissions = "CRUD";
      };
      audio-library = {
        password = "{env}AUDIO_LIBRARY_PASSWORD";
        directory = "/media/tomcotton/audio-library";
        permissions = "R";
      };
      media-readonly = {
        password = "{env}MEDIA_RO_PASSWORD";
        directory = "/media";
        permissions = "R";
        # these are evaluated in reverse order
        rules = [
          {
            regex = ".*";
            permissions = "none";
          }
          # This is the directory listing
          {
            regex = "^/$";
            permissions = "R";
          }
          {
            regex = "music|movies|books";
            permissions = "R";
          }
        ];
      };
      paperless-bcotton = {
        password = "{env}BCOTTON_PAPERLESS_PASSWORD";
        directory = "/var/lib/paperless/consume/bcotton";
        permissions = "CRUD";
      };
    };
  };

  services.clubcotton.wallabag = {
    dataDir = "/media/documents/wallabag";
  };

  services.clubcotton.kavita = {
    user = "share";
    port = 8085;
    dataDir = "/var/lib/kavita";
    # Specify library directory separately from dataDir for better organization
    libraryDir = "/media/books/kavita";
    # List users who should have access to the libraries
    # sharedUsers = [ "tomcotton" ];  # Add more users as needed
    tokenKeyFile = config.age.secrets."kavita-token".path;
    bindAddresses = ["0.0.0.0" "::"];
    tailnetHostname = "kavita";
  };

  services.clubcotton.forgejo = {
    port = 3000;
    sshPort = 2222;
    domain = "nas-01";
    customPath = "/ssdpool/local/forgejo";
    tailnetHostname = "forgejo";
    database = {
      enable = true;
      # Database is managed by services.clubcotton.postgresql.forgejo
      passwordFile = config.age.secrets."forgejo-db-password".path;
    };
    features = {
      actions = true;
      packages = true;
      lfs = true;
      federation = false;
    };
  };

  # This is here and not in the webdav module because of fuckery
  # rg fuckery
  services.tsnsrv = {
    enable = true;
    defaults.authKeyPath = config.clubcotton.tailscaleAuthKeyPath;
    services.webdav = {
      ephemeral = true;
      toURL = "http://127.0.0.1:6065";
    };
    services.nix-cache = {
      ephemeral = true;
      toURL = "http://127.0.0.1:${toString config.services.clubcotton.nix-cache-proxy.port}";
    };
  };

  programs.zsh.enable = variables.zshEnable;

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA51nSUvq7WevwvTYzD1S2xSr9QU7DVuYu3k/BGZ7vJ0 bob.cotton@gmail.com"
    ];
  };
  services.openssh = {
    enable = true;
    settings = {
      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
        "umac-128-etm@openssh.com"

        # This are needed for Arq (libssh2)
        "hmac-sha2-512"
      ];
    };
  };

  # SSH client configuration (keepalive settings)
  programs.ssh.extraConfig = ''
    Host *
      ServerAliveCountMax 60
      ServerAliveInterval 60
  '';

  networking.firewall.enable = variables.firewallEnable;
  networking.hostId = "007f0200";

  # CUPS PDF service for paperless consumption
  services.printing = {
    enable = true;
    # Enable network printing and sharing
    listenAddresses = ["*:631"];
    allowFrom = ["all"];
    browsing = true;
    defaultShared = true;
  };

  # Enable Avahi for printer discovery
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  services.printing.cups-pdf = {
    enable = true;
    instances = {
      # Disable the default pdf instance
      pdf.enable = false;

      bcotton = {
        enable = true;
        installPrinter = true;
        settings = {
          Out = "/var/lib/paperless/consume/bcotton";
          AnonDirName = "/var/lib/paperless/consume/bcotton"; # Anonymous users go to same directory
          UserUMask = "0000"; # More permissive - creates files with 666 permissions
          Grp = "paperless"; # Set group to paperless so paperless service can access
          UserPrefix = "";
          TitlePref = "TRUE";
          Label = "1";
          Anonuser = "bcotton"; # Allow anonymous access, treat as bcotton user
          GhostScript = "${pkgs.ghostscript}/bin/gs";
        };
      };

      tomcotton = {
        enable = true;
        installPrinter = true;
        settings = {
          Out = "/var/lib/paperless/consume/tomcotton";
          AnonDirName = "/var/lib/paperless/consume/tomcotton"; # Anonymous users go to same directory
          UserUMask = "0000";
          Grp = "paperless";
          UserPrefix = "";
          TitlePref = "TRUE";
          Label = "1";
          Anonuser = "tomcotton"; # Allow anonymous access, treat as tomcotton user
          GhostScript = "${pkgs.ghostscript}/bin/gs";
        };
      };
    };
  };

  # Create consumption directories and set permissions
  # Make directories writable by cups user and owned by respective users
  systemd.tmpfiles.rules = [
    "d /var/lib/paperless/consume/bcotton 0775 bcotton lp - -"
    "d /var/lib/paperless/consume/tomcotton 0775 tomcotton lp - -"
  ];

  # Ensure users are in the lp group so cups can write files they can read
  users.users.bcotton.extraGroups = ["lp"];
  users.users.tomcotton.extraGroups = ["lp"];
  # Add cups user to paperless group for better file access
  users.users.cups.extraGroups = ["paperless"];

  clubcotton.zfs_mirrored_root = {
    enable = true;
    poolname = "rpool";
    swapSize = "64G";
    disks = [
      "/dev/disk/by-id/ata-WD_Blue_SA510_2.5_1000GB_24293W800136"
      "/dev/disk/by-id/ata-SPCC_Solid_State_Disk_AAAA0000000000006990"
    ];
    useStandardRootFilesystems = true;
    reservedSize = "20GiB";
  };
  boot.zfs.extraPools = ["ssdpool" "mediapool" "backuppool"];

  clubcotton.zfs_raidz1 = {
    ssdpool = {
      enable = true;
      disks = [
        "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X903171J"
        "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X903188X"
        "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X903194N"
        "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X905916M"
      ];
      # filesystems = {
      #   "ssdpool/local/forgejo" = {
      #     mountpoint = "/ssdpool/local/forgejo";
      #     options = {
      #       compression = "lz4";
      #       atime = "off";
      #       quota = "200G";
      #     };
      #   };
      # };
      # filesystems = {
      #   "local/nix-cache" = {
      #     mountpoint = "/ssdpool/local/nix-cache";
      #     options = {
      #       compression = "lz4";
      #       atime = "off";
      #       quota = "500G";
      #     };
      #   };
      # };
      volumes = {
        "local/incus" = {
          size = "300G";
        };
      };
    };

    mediapool = {
      enable = true;
      disks = [
        "/dev/disk/by-id/wwn-0x5000c500cbac2c8c"
        "/dev/disk/by-id/wwn-0x5000c500cbadaef8"
        "/dev/disk/by-id/wwn-0x5000c500f73da9f5"
      ];
    };
    backuppool = {
      enable = true;
      disks = [
        "/dev/disk/by-id/wwn-0x5000c500cb986994"
        "/dev/disk/by-id/wwn-0x5000c500cb5e1c80"
        "/dev/disk/by-id/wwn-0x5000c500f6f25ea9"
      ];
    };
  };

  services.sanoid = {
    datasets."ssdpool/local/database" = {
      useTemplate = ["backup"];
    };
    datasets."ssdpool/local/nix-cache" = {
      useTemplate = ["backup"];
    };
    datasets."mediapool/local/photos" = {
      useTemplate = ["media"];
    };
    datasets."mediapool/local/documents" = {
      useTemplate = ["media"];
    };
    datasets."mediapool/local/tomcotton/data" = {
      useTemplate = ["media"];
    };
    datasets."mediapool/local/tomcotton/audio-library" = {
      useTemplate = ["media"];
    };
  };

  # Enhanced monitoring for nas-01 specific disks
  services.prometheus.exporters.smartctl = {
    devices = [
      # rpool (mirrored root) disks
      "/dev/disk/by-id/ata-WD_Blue_SA510_2.5_1000GB_24293W800136"
      "/dev/disk/by-id/ata-SPCC_Solid_State_Disk_AAAA0000000000006990"
      # ssdpool (RAIDZ1) NVMe drives
      "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X903171J"
      "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X903188X"
      "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X903194N"
      "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X905916M"
      # mediapool (RAIDZ1) drives
      "/dev/disk/by-id/wwn-0x5000c500cbac2c8c"
      "/dev/disk/by-id/wwn-0x5000c500cbadaef8"
      "/dev/disk/by-id/wwn-0x5000c500f73da9f5"
      # backuppool (RAIDZ1) drives
      "/dev/disk/by-id/wwn-0x5000c500cb986994"
      "/dev/disk/by-id/wwn-0x5000c500cb5e1c80"
      "/dev/disk/by-id/wwn-0x5000c500f6f25ea9"
    ];
  };

  # Nix build and cache infrastructure monitoring
  services.prometheus.nixBuildCacheCheck = {
    enable = true;
    interval = "15m";
    cacheUrl = "http://nas-01:80";
  };

  system.stateVersion = "24.11"; # Did you read the comment?
}
