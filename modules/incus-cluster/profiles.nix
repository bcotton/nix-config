{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.incus-cluster;

  # Profile submodule type
  profileType = types.submodule ({name, ...}: {
    options = {
      description = mkOption {
        type = types.str;
        default = "Incus profile: ${name}";
        description = "Human-readable description.";
      };

      cpu = mkOption {
        type = types.int;
        description = "CPU core limit.";
      };

      memory = mkOption {
        type = types.str;
        description = "Memory limit (e.g. \"4GiB\").";
      };

      diskSize = mkOption {
        type = types.str;
        description = "Root disk size (e.g. \"20GiB\").";
      };

      storagePool = mkOption {
        type = types.str;
        default = "local";
        description = "Storage pool for the root disk.";
      };

      secureboot = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable secure boot (VMs only).";
      };

      nesting = mkOption {
        type = types.bool;
        default = false;
        description = "Allow security nesting (required for NixOS containers).";
      };

      extraConfig = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Extra incus config key=value pairs for the profile.";
      };

      devices = mkOption {
        type = types.attrsOf (types.attrsOf types.str);
        default = {};
        description = ''
          Extra devices for the profile. Each device is an attrset with
          a required "type" key and optional properties.
          Example: { eth0 = { type = "nic"; nictype = "bridged"; parent = "br0"; }; }
        '';
      };
    };
  });

  # Consistent maxcpus across heterogeneous cluster nodes.
  # Without this, QEMU uses the host's physical thread count as maxcpus,
  # which causes ICH9LPC device state migration failures between hosts
  # with different core counts (e.g. Ryzen 16T vs EPYC 48T).
  # Must be set to the minimum thread count in the cluster (16 for nix-01/02/03).
  qemuMigrationCompat = {
    "raw.qemu.conf" = ''
      [smp-opts]
      cpus = "1"
      maxcpus = "16"
    '';
  };

  # Default values for profile fields not explicitly set
  profileDefaults = {
    storagePool = "local";
    secureboot = false;
    nesting = false;
    extraConfig = {};
    devices = {};
  };

  # Built-in profile definitions
  builtinProfiles = builtins.mapAttrs (_: p: profileDefaults // p) {
    small = {
      description = "Small instance: 2 CPU, 4GiB RAM, 20GiB disk";
      cpu = 2;
      memory = "4GiB";
      diskSize = "20GiB";
      nesting = true;
    };

    medium = {
      description = "Medium instance: 4 CPU, 8GiB RAM, 40GiB disk";
      cpu = 4;
      memory = "8GiB";
      diskSize = "40GiB";
      nesting = true;
    };

    large = {
      description = "Large instance: 8 CPU, 16GiB RAM, 80GiB disk";
      cpu = 8;
      memory = "16GiB";
      diskSize = "80GiB";
      nesting = true;
    };

    haos = {
      description = "Home Assistant OS VM";
      cpu = 4;
      memory = "8GiB";
      diskSize = "64GiB";
      extraConfig = {
        "boot.autostart" = "true";
      };
    };

    ephemeral = {
      description = "Ephemeral instance for CI/shadow testing";
      cpu = 2;
      memory = "2GiB";
      diskSize = "10GiB";
      nesting = true;
    };
  };

  # Merge built-in profiles with user-defined ones (user can override built-ins)
  allProfiles = builtinProfiles // cfg.profiles;

  # Convert a profile definition to preseed format
  profileToPreseed = name: profile: {
    inherit name;
    description = profile.description;
    config =
      {
        "limits.cpu" = toString profile.cpu;
        "limits.memory" = profile.memory;
        "security.secureboot" = boolToString profile.secureboot;
      }
      // qemuMigrationCompat
      // optionalAttrs profile.nesting {
        "security.nesting" = "true";
      }
      // profile.extraConfig;
    devices =
      {
        root = {
          path = "/";
          pool = profile.storagePool;
          size = profile.diskSize;
          type = "disk";
        };
      }
      // profile.devices;
  };
in {
  options.services.incus-cluster.profiles = mkOption {
    type = types.attrsOf profileType;
    default = {};
    description = ''
      Additional incus profiles. Built-in profiles (small, medium, large, haos, ephemeral)
      are always available and can be overridden.
    '';
  };

  config = mkIf cfg.enable {
    # Push profiles into incus preseed
    virtualisation.incus.preseed.profiles =
      mapAttrsToList profileToPreseed allProfiles;
  };
}
