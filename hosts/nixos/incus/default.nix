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
    ./disk-config.nix
    ./hardware-configuration.nix
  ];

  users.users.root = {
    openssh.authorizedKeys.keys = keys.rootAuthorizedKeys;
  };

  networking.hostId = "420cbfd4";

  fileSystems."/".fsType = lib.mkForce "zfs";
  fileSystems."/".device = lib.mkForce "rpool/local/root";
  fileSystems."/".autoResize = lib.mkForce false;

  boot.initrd.supportedFilesystems = ["zfs"];
  boot.supportedFilesystems = ["zfs"];
  boot.zfs.forceImportRoot = false;

  # This is from https://github.com/KornelJahn/nixos-disko-zfs-test
  # understand all that is happening.
  boot = {
    kernelParams = [
      "nohibernate"
      # WORKAROUND: get rid of error
      # https://github.com/NixOS/nixpkgs/issues/35681
      "systemd.gpt_auto=0"
      "zfs.zfs_arc_max=${toString (512 * 1048576)}"
      "boot.shell_on_fail"
    ];

    loader = {
      systemd-boot.enable = lib.mkForce false;
      grub = {
        enable = lib.mkForce true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        mirroredBoots = [
          {
            devices = ["nodev"];
            path = "/boot1";
            efiSysMountPoint = "/boot1";
          }
          {
            devices = ["nodev"];
            path = "/boot2";
            efiSysMountPoint = "/boot2";
          }
        ];
      };
    };
  };

  services = {
    openssh = {
      enable = true;
    };

    zfs = {
      trim.enable = true;
      autoScrub = {
        enable = true;
        pools = ["rpool"];
      };
    };
  };

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
