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

  services.clubcotton.jellyfin = {
    enable = true;
    tailnetHostname = "jellyfin";
  };
  programs.zsh.enable = true;

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA51nSUvq7WevwvTYzD1S2xSr9QU7DVuYu3k/BGZ7vJ0 bob.cotton@gmail.com"
    ];
  };
  services.openssh.enable = true;
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
          mountpoint = "/media/tomcotton/documents";
          options = {
            mountpoint = "legacy";
            "com.sun:auto-snapshot" = "true"; 
          };
        };
        "local/tomcotton/cold-data" = { # Separated for alternate possible offsite backup method
          type = "zfs_fs";
          mountpoint = "/media/tomcotton/documents";
          options = {
            mountpoint = "legacy";
            "com.sun:auto-snapshot" = "true"; 
          };
        };
        "local/tomcotton/audio-library" = {
          type = "zfs_fs";
          mountpoint = "/media/tomcotton/audio-library";
          options = {
            mountpoint = "legacy";
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
        "local/backups/toms-mini" = { # Seperate backups filesystems for simpler snapshotting
          type = "zfs_fs";
          mountpoint = "/backups/toms-mini";
          options = {
            mountpoint = "legacy";
            recordsize = "1M"; # for large files
            "com.sun:auto-snapshot" = "true";
          };
        };
        "local/backups/toms-MBP" = { # Seperate backups filesystems for simpler snapshotting
          type = "zfs_fs";
          mountpoint = "/backups/toms-MBP";
          options = {
            mountpoint = "legacy";
            recordsize = "1M"; # for large files
            "com.sun:auto-snapshot" = "true";
          };
        };
        "local/backups/toms-devices" = { # iPhone etc...
          type = "zfs_fs";
          mountpoint = "/backups/toms-devices";
          options = {
            mountpoint = "legacy";
            recordsize = "1M"; # for large files
            "com.sun:auto-snapshot" = "true";
          };
        };
        # EX: backups/nix-01 
        # EX: backups/nix-02
        # EX: etc...
      }; # filesystems
    };
  };

  system.stateVersion = "24.11"; # Did you read the comment?
}
