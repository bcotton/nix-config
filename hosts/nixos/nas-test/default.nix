# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  modulesPath,
  lib,
  ...
}: {
  imports = [
    # Include the default incus configuration.
    # "${modulesPath}/virtualisation/incus-virtual-machine.nix"
    ./hardware-configuration.nix
  ];

  time.timeZone = "America/Denver";

  programs.zsh.enable = true;

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA51nSUvq7WevwvTYzD1S2xSr9QU7DVuYu3k/BGZ7vJ0 bob.cotton@gmail.com"
    ];
  };
  services.openssh.enable = true;
  networking.firewall.enable = false;

  networking.hostId = "420cbfd4";
  # boot.loader.systemd-boot.enable = true;

  clubcotton.zfs_mirrored_root = {
    enable = true;
    poolname = "rpool";
    swapSize = "128M";
    disks = [
      "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_incus_root"
      "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_incus_drive1"
    ];
    filesystems = {
      local = {
        type = "zfs_fs";
        options.mountpoint = "none";
      };
      safe = {
        type = "zfs_fs";
        options.mountpoint = "none";
      };
      "local/reserved" = {
        type = "zfs_fs";
        options = {
          mountpoint = "none";
          reservation = "5GiB";
        };
      };
      "local/root" = {
        type = "zfs_fs";
        mountpoint = "/";
        options.mountpoint = "legacy";
        postCreateHook = ''
          zfs snapshot rpool/local/root@blank
        '';
      };
      "local/nix" = {
        type = "zfs_fs";
        mountpoint = "/nix";
        options = {
          atime = "off";
          canmount = "on";
          mountpoint = "legacy";
          "com.sun:auto-snapshot" = "true";
        };
      };
      "local/log" = {
        type = "zfs_fs";
        mountpoint = "/var/log";
        options = {
          mountpoint = "legacy";
          "com.sun:auto-snapshot" = "true";
        };
      };
      "local/lib" = {
        type = "zfs_fs";
        mountpoint = "/var/lib";
        options = {
          mountpoint = "legacy";
          "com.sun:auto-snapshot" = "true";
        };
      };
      "safe/home" = {
        type = "zfs_fs";
        mountpoint = "/home";
        options = {
          mountpoint = "legacy";
          "com.sun:auto-snapshot" = "true";
        };
      };
    }; # filesystems
    volumes = {
      "local/incus" = {
        size = "30M";
      };
    };
  };

  clubcotton.zfs_single_root = {
    enable = false;
    poolname = "testpool";
    swapSize = "128M";
    disk = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_incus_root";
    filesystems = {
      "root" = {
        type = "zfs_fs";
        mountpoint = "/";
        options.mountpoint = "legacy";
      };
      "nix" = {
        type = "zfs_fs";
        mountpoint = "/nix";
        options = {
          mountpoint = "legacy";
          "com.sun:auto-snapshot" = "true";
        };
      };
    };
  };

  clubcotton.zfs_raidz1 = {
    ssdpool = {
      enable = true;
      disks = [
        "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_incus_nvme1"
        "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_incus_nvme2"
        "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_incus_nvme3"
        "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_incus_nvme4"
      ];
      filesystems = {
        database = {
          type = "zfs_fs";
          mountpoint = "/db";
          options = {
            mountpoint = "legacy";
            recordsize = "8k"; # for postgres
            "com.sun:auto-snapshot" = "true";
          };
        };
      };
    };
    backuppool = {
      enable = true;
      disks = [
        "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_incus_nvme5"
        "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_incus_nvme6"
        "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_incus_nvme7"
      ];
      filesystems = {
        database = {
          type = "zfs_fs";
          mountpoint = "/db2";
          options = {
            mountpoint = "legacy";
            recordsize = "8k"; # for postgres
            "com.sun:auto-snapshot" = "true";
          };
        };
      };
    };
  };

  boot.kernelParams = [
    "boot.shell_on_fail"
  ];

  # This is for incus networking
  networking = {
    dhcpcd.enable = false;
    useDHCP = false;
    useHostResolvConf = false;
  };

  systemd.network = {
    enable = true;
    networks."50-enp5s0" = {
      matchConfig.Name = "enp5s0";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
      };
      linkConfig = {
        MACAddress = "40:5b:d6:a8:5b:cb";
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };

  system.stateVersion = "25.05"; # Did you read the comment?
}
