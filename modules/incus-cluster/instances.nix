{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.incus-cluster;

  # Device submodule for disk mounts, USB passthrough, etc.
  deviceType = types.submodule {
    options = {
      type = mkOption {
        type = types.enum ["disk" "usb" "nic" "gpu" "unix-char" "unix-block"];
        description = "Device type.";
      };

      properties = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Device properties (source, path, vendorid, productid, etc.).";
      };
    };
  };

  # Instance submodule type
  instanceType = types.submodule ({name, ...}: {
    options = {
      type = mkOption {
        type = types.enum ["vm" "container"];
        description = "Instance type: virtual-machine or container.";
      };

      deploy = mkOption {
        type = types.enum ["image" "opaque"];
        default = "image";
        description = ''
          Deployment strategy:
          - image: Build NixOS image from nixosConfigurations and import as incus image
          - opaque: Import external image (QCOW2 + metadata), manage lifecycle only
        '';
      };

      configuration = mkOption {
        type = types.nullOr types.str;
        default = name;
        description = ''
          nixosConfigurations attribute name to build the image from.
          Only used when deploy = "image". Set to null for opaque instances.
        '';
      };

      profile = mkOption {
        type = types.str;
        default = "small";
        description = "Incus profile name to apply.";
      };

      storagePool = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Override the profile's storage pool for the root disk.";
      };

      autostart = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to start the instance on boot.";
      };

      devices = mkOption {
        type = types.attrsOf deviceType;
        default = {};
        description = "Additional devices (NFS mounts, USB passthrough, etc.).";
        example = literalExpression ''
          {
            media = {
              type = "disk";
              properties = {
                source = "/mnt/media";
                path = "/media";
              };
            };
            zigbee = {
              type = "usb";
              properties = {
                vendorid = "10c4";
                productid = "ea60";
              };
            };
          }
        '';
      };

      network = mkOption {
        type = types.submodule {
          options = {
            mode = mkOption {
              type = types.enum ["bridged" "managed" "macvlan"];
              default = "bridged";
              description = "Network mode.";
            };

            parent = mkOption {
              type = types.str;
              default = "br0";
              description = "Parent network/bridge for bridged/macvlan mode.";
            };

            hwaddr = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Fixed MAC address for DHCP reservation.";
            };
          };
        };
        default = {};
        description = "Network configuration.";
      };

      extraConfig = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Extra incus config key=value pairs for the instance.";
      };

      # Opaque image settings
      imagePath = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to QCOW2 or rootfs image (for opaque deploy strategy).";
      };

      metadataPath = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to metadata tarball (for opaque deploy strategy).";
      };

      imageAlias = mkOption {
        type = types.str;
        default = name;
        description = "Incus image alias for this instance.";
      };

      target = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Cluster member to place this instance on (e.g. \"nix-01\"). If null, the scheduler decides.";
      };
    };
  });
in {
  options.services.incus-cluster.instances = mkOption {
    type = types.attrsOf instanceType;
    default = {};
    description = "Incus instances to manage declaratively.";
  };
}
