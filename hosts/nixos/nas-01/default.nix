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
    ../../../modules/tailscale
    ../../../modules/samba
  ];

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

  services.clubcotton.services.tailscale.enable = true;

  services.nfs.server.enable = true;
  services.rpcbind.enable = true;

  # Set your time zone.
  time.timeZone = "America/Denver";

  services.clubcotton.sabnzbd = {
    enable = true;
    tailnetHostname = "sabnzbd";
  };

  services.clubcotton.radarr = {
    enable = true;
    tailnetHostname = "radarr";
  };

  services.clubcotton.sonarr = {
    enable = true;
    tailnetHostname = "sonarr";
  };

  services.clubcotton.prowlarr = {
    enable = true;
    tailnetHostname = "prowlarr";
  };

  services.clubcotton.lidarr = {
    enable = true;
    tailnetHostname = "lidarr";
  };

  services.clubcotton.readarr = {
    enable = true;
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

  services.clubcotton.calibre = {
    enable = true;
    tailnetHostname = "calibre";
  };

  services.clubcotton.calibre-web = {
    enable = true;
    tailnetHostname = "calibre-web";
  };

  services.clubcotton.jellyfin = {
    enable = true;
    tailnetHostname = "jellyfin";
  };

  services.clubcotton.roon-server.enable = true;

  systemd.services.webdav.serviceConfig = {
    StateDirectory = "webdav";
    EnvironmentFile = config.age.secrets.webdav.path;
  };

  services.clubcotton.webdav = {
    enable = true;
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
    };
  };
  # Expose this code-server as a host on the tailnet
  # This is here and not in the webdav module because of fuckery
  # rg fuckery
  services.tsnsrv = {
    enable = true;
    defaults.authKeyPath = config.clubcotton.tailscaleAuthKeyPath;
    services.webdav = {
      ephemeral = true;
      toURL = "http//127.0.0.1:6065";
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
      "/dev/disk/by-id/wwn-0x500a0751e8afe231"
    ];
    useStandardRootFilesystems = true;
    reservedSize = "20GiB";
  };

  clubcotton.zfs_raidz1 = {
    ssdpool = {
      enable = true;
      disks = [
        "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X903171J"
        "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X903188X"
        "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X903194N"
        "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X905916M"
      ];
      filesystems = {
        local = {
          options.mountpoint = "none";
        };
        "local/reserved" = {
          type = "zfs_fs";
          options = {
            mountpoint = "none";
            reservation = "200GiB";
          };
        };
        "local/database" = {
          type = "zfs_fs";
          mountpoint = "/db";
          options = {
            mountpoint = "legacy";
            recordsize = "8k"; # for postgres
            "com.sun:auto-snapshot" = "true";
          };
        };
      }; # filesystems
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
      filesystems = {
        local = {
          options.mountpoint = "none";
        };
        "local/reserved" = {
          type = "zfs_fs";
          options = {
            mountpoint = "none";
            reservation = "600GiB";
          };
        };
        "local/music" = {
          type = "zfs_fs";
          mountpoint = "/media/music";
          options = {
            mountpoint = "legacy";
            recordsize = "1M"; # for larege files
            "com.sun:auto-snapshot" = "true";
          };
        };
        "local/movies" = {
          type = "zfs_fs";
          mountpoint = "/media/movies";
          options = {
            mountpoint = "legacy";
            recordsize = "1M"; # for larege files
            "com.sun:auto-snapshot" = "true";
          };
        };
        "local/shows" = {
          type = "zfs_fs";
          mountpoint = "/media/shows";
          options = {
            mountpoint = "legacy";
            recordsize = "1M"; # for large files
            "com.sun:auto-snapshot" = "true";
          };
        };
        "local/books" = {
          type = "zfs_fs";
          mountpoint = "/media/books";
          options = {
            mountpoint = "legacy";
            recordsize = "1M"; # for large files
            "com.sun:auto-snapshot" = "true";
          };
        };
        "local/photots" = {
          type = "zfs_fs";
          mountpoint = "/media/photos";
          options = {
            mountpoint = "legacy";
            "com.sun:auto-snapshot" = "true";
          };
        };
        # webdav tree
        "local/webdav" = {
          type = "zfs_fs";
          mountpoint = "/media/webdav";
          options = {
            "com.sun:auto-snapshot" = "false";
          };
        };
        # tomcotton tree
        "local/tomcotton" = {
          type = "zfs_fs";
          mountpoint = "/media/tomcotton";
          options = {
            mountpoint = "legacy";
            "com.sun:auto-snapshot" = "false"; # Parent FS, no data
          };
        };
        "local/tomcotton/data" = {
          type = "zfs_fs";
          mountpoint = "/media/tomcotton/data";
          options = {
            "com.sun:auto-snapshot" = "true";
          };
        };
        "local/tomcotton/cold-data" = {
          # Separated for alternate possible offsite backup method
          type = "zfs_fs";
          mountpoint = "/media/tomcotton/cold-data";
          options = {
            "com.sun:auto-snapshot" = "true";
          };
        };
        "local/tomcotton/audio-library" = {
          type = "zfs_fs";
          mountpoint = "/media/tomcotton/audio-library";
          options = {
            "com.sun:auto-snapshot" = "true";
          };
        };
      }; # filesystems
    };
    backuppool = {
      enable = true;
      disks = [
        "/dev/disk/by-id/wwn-0x5000c500cb986994"
        "/dev/disk/by-id/wwn-0x5000c500cb5e1c80"
        "/dev/disk/by-id/wwn-0x5000c500f6f25ea9"
      ];
      filesystems = {
        local = {
          options.mountpoint = "none";
        };
        "local/reserved" = {
          type = "zfs_fs";
          options = {
            mountpoint = "none";
            reservation = "600GiB";
          };
        };
        "local/backups" = {
          type = "zfs_fs";
          mountpoint = "/backups";
          options = {
            mountpoint = "legacy";
            recordsize = "1M"; # for large files
            "com.sun:auto-snapshot" = "true";
          };
        };
        "local/tomcotton/toms-mini" = {
          type = "zfs_fs";
          mountpoint = "/backups/tomcotton/toms-mini";
        };
        "local/tomcotton/toms-MBP" = {
          type = "zfs_fs";
          mountpoint = "/backups/tomcotton/toms-MBP";
        };
      }; # filesystems
    };
  };

  system.stateVersion = "24.11"; # Did you read the comment?
}
