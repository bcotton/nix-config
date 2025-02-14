# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  config,
  pkgs,
  unstablePkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../../modules/node-exporter
    ../../../modules/samba
  ];

  services.clubcotton = {
    atuin.enable = true;
    calibre.enable = true;
    calibre-web.enable = true;
    filebrowser.enable = true;
    freshrss.enable = true;
    immich.enable = true;
    jellyfin.enable = true;
    kavita.enable = false;
    lidarr.enable = true;
    navidrome.enable = true;
    open-webui.enable = true;
    paperless.enable = false;
    postgresql.enable = true;
    prowlarr.enable = true;
    radarr.enable = true;
    readarr.enable = true;
    roon-server.enable = true;
    sabnzbd.enable = true;
    sonarr.enable = true;
    tailscale.enable = true;
    webdav.enable = true;
  };

  networking = {
    hostName = "nas-01";
    defaultGateway = "192.168.5.1";
    nameservers = ["192.168.5.220"];
    interfaces.enp0s31f6.ipv4.addresses = [
      {
        address = "192.168.5.300";
        prefixLength = 24;
      }
    ];
  };

  users = {
    groups.share = {
      gid = 993;
    };
    users.share = {
      uid = 994;
      isSystemUser = true;
      group = "share";
    };
  };

  services.nfs.server = {
    enable = true;
  };
  services.rpcbind.enable = true;

  # Set your time zone.
  time.timeZone = "America/Denver";

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
    freshrss = {
      enable = true;
      passwordFile = config.age.secrets."freshrss-database".path;
    };
    paperless = {
      enable = true;
      passwordFile = config.age.secrets."paperless-database".path;
    };
  };

  services.clubcotton.filebrowser = {
    port = 8082;
    tailnetHostname = "files";
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
    tailnetHostname = "llm";
    environment = {
      WEBUI_AUTH = "True";
      ENABLE_OLLAMA_API = "True";
      OLLAMA_BASE_URL = "http://toms-mini:11434";
      OLLAMA_API_BASE_URL = "http://toms-mini:11434";
    };
    environmentFile = config.age.secrets.open-webui.path;
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
    };
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

  # This is here and not in the webdav module because of fuckery
  # rg fuckery
  services.tsnsrv = {
    enable = true;
    defaults.authKeyPath = config.clubcotton.tailscaleAuthKeyPath;
    services.webdav = {
      ephemeral = true;
      toURL = "http://127.0.0.1:6065";
    };
  };

  programs.zsh.enable = true;

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

  networking.firewall.enable = false;
  networking.hostId = "007f0200";

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

  system.stateVersion = "24.11"; # Did you read the comment?
}
