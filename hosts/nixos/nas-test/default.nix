# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  modulesPath,
  lib,
  hostName,
  ...
}: let
  # Get merged variables (defaults + host overrides)
  commonLib = import ../../common/lib.nix;
  variables = commonLib.getHostVariables hostName;
  keys = import ../../common/keys.nix;
in {
  imports = [
    # Include the default incus configuration.
    # "${modulesPath}/virtualisation/incus-virtual-machine.nix"
    ./hardware-configuration.nix
  ];

  time.timeZone = variables.timeZone;

  programs.zsh.enable = variables.zshEnable;

  users.users.root = {
    openssh.authorizedKeys.keys = keys.rootAuthorizedKeys;
  };
  services.openssh.enable = variables.opensshEnable;
  networking.firewall.enable = variables.firewallEnable;

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
    useStandardRootFilesystems = true;
    reservedSize = "5GiB";
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

  system.stateVersion = variables.stateVersion;
}
