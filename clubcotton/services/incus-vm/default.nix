{
  config,
  lib,
  pkgs,
  self,
  ...
}:
with lib; let
  cfg = config.services.clubcotton.incus-vm;
in {
  options.services.clubcotton.incus-vm = {
    enable = mkEnableOption "Declarative Incus VM lifecycle management";

    instances = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          configuration = mkOption {
            type = types.str;
            default = name;
            description = "nixosConfigurations attribute name to build the VM image from.";
          };

          cpu = mkOption {
            type = types.int;
            default = 2;
            description = "CPU core limit for the VM.";
          };

          memory = mkOption {
            type = types.str;
            default = "4GiB";
            description = "Memory limit for the VM (e.g. \"4GiB\", \"8GiB\").";
          };

          diskSize = mkOption {
            type = types.str;
            default = "20GiB";
            description = "Root disk size for the VM.";
          };

          secureboot = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to enable secure boot for the VM.";
          };

          nesting = mkOption {
            type = types.bool;
            default = false;
            description = "Allow nesting (required for running Incus inside the VM).";
          };

          autostart = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to start the VM on boot.";
          };

          zfsPool = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "ZFS storage pool name for the root disk. If null, uses Incus default pool.";
          };

          mounts = mkOption {
            type = types.attrsOf (types.submodule {
              options = {
                source = mkOption {
                  type = types.str;
                  description = "Host path to mount in the VM.";
                };

                path = mkOption {
                  type = types.str;
                  description = "Mount path inside the VM.";
                };

                readonly = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether the mount is read-only.";
                };
              };
            });
            default = {};
            description = "Host paths to mount in the VM via disk devices.";
          };

          extraConfig = mkOption {
            type = types.attrsOf types.str;
            default = {};
            description = "Extra incus config key=value pairs to set on the instance.";
          };
        };
      }));
      default = {};
      description = "Incus VM instances to manage declaratively.";
      example = literalExpression ''
        {
          incus-testing = {
            configuration = "incus-testing";
            cpu = 4;
            memory = "8GiB";
            diskSize = "50GiB";
            secureboot = false;
            nesting = true;
            zfsPool = "local";
          };
        }
      '';
    };
  };

  config = mkIf (cfg.enable && cfg.instances != {}) {
    assertions = [
      {
        assertion = config.virtualisation.incus.enable;
        message = "services.clubcotton.incus-vm requires virtualisation.incus.enable = true";
      }
    ];

    systemd.services =
      mapAttrs' (
        name: instanceCfg: let
          guestConfig = self.nixosConfigurations.${instanceCfg.configuration};
          qemuImage = guestConfig.config.system.build.qemuImage;
          metadata = guestConfig.config.system.build.metadata;
          imageAlias = "nixos-${instanceCfg.configuration}";

          # Build the incus launch flags
          launchFlags = concatStringsSep " " (
            [
              "--vm"
              "-c security.secureboot=${boolToString instanceCfg.secureboot}"
              "-c limits.cpu=${toString instanceCfg.cpu}"
              "-c limits.memory=${instanceCfg.memory}"
              "-d root,size=${instanceCfg.diskSize}"
            ]
            ++ optional instanceCfg.nesting "-c security.nesting=true"
            ++ optional (instanceCfg.zfsPool != null) "-d root,pool=${instanceCfg.zfsPool}"
            ++ mapAttrsToList (k: v: "-c ${k}=${v}") instanceCfg.extraConfig
          );

          # Script to ensure image is imported and instance exists
          startPreScript = pkgs.writeShellScript "incus-vm-${name}-start-pre" ''
            set -euo pipefail
            export PATH="${lib.makeBinPath [pkgs.incus pkgs.coreutils]}:$PATH"

            IMAGE_ALIAS="${imageAlias}"
            INSTANCE_NAME="${name}"
            QEMU_IMAGE="${qemuImage}/nixos.qcow2"

            # Find the metadata tarball via glob
            METADATA_FILE=("${metadata}/tarball/"*.tar.xz)
            if [ ! -f "''${METADATA_FILE[0]}" ]; then
              echo "ERROR: No metadata tarball found in ${metadata}/tarball/"
              exit 1
            fi

            # Check if instance already exists
            if incus info "$INSTANCE_NAME" &>/dev/null; then
              echo "Instance $INSTANCE_NAME already exists, nothing to do"
            else
              echo "Importing image as $IMAGE_ALIAS..."
              # Delete old alias if it exists (might point to stale image)
              incus image alias delete "$IMAGE_ALIAS" 2>/dev/null || true
              incus image import "''${METADATA_FILE[0]}" "$QEMU_IMAGE" --alias "$IMAGE_ALIAS"

              echo "Launching instance $INSTANCE_NAME..."
              incus launch "$IMAGE_ALIAS" "$INSTANCE_NAME" ${launchFlags}

              # Instance was just created and started by launch, signal ExecStart to skip
              touch /run/incus-vm-${name}.launched
            fi

            ${concatStringsSep "\n" (mapAttrsToList (mountName: mountCfg: ''
                # Add disk device: ${mountName}
                if ! incus config device get "$INSTANCE_NAME" "${mountName}" source &>/dev/null; then
                  echo "Adding disk device ${mountName}: ${mountCfg.source} -> ${mountCfg.path}"
                  incus config device add "$INSTANCE_NAME" "${mountName}" disk \
                    source="${mountCfg.source}" \
                    path="${mountCfg.path}" \
                    ${optionalString mountCfg.readonly "readonly=true"}
                fi
              '')
              instanceCfg.mounts)}
          '';
        in
          nameValuePair "incus-vm-${name}" {
            description = "Incus VM: ${name}";
            after = ["incus.service" "incus-preseed.service"];
            requires = ["incus.service"];
            wantedBy = optional instanceCfg.autostart "multi-user.target";

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              TimeoutStartSec = "5min";
              ExecStartPre = "${startPreScript}";
              ExecStart = pkgs.writeShellScript "incus-vm-${name}-start" ''
                set -euo pipefail
                export PATH="${lib.makeBinPath [pkgs.incus]}:$PATH"

                # If just launched by ExecStartPre, skip start
                if [ -f /run/incus-vm-${name}.launched ]; then
                  rm -f /run/incus-vm-${name}.launched
                  echo "Instance ${name} already started by launch"
                  exit 0
                fi

                # Start if not already running
                STATUS=$(incus info "${name}" 2>/dev/null | grep "^Status:" | awk '{print $2}' || echo "Unknown")
                if [ "$STATUS" != "RUNNING" ]; then
                  echo "Starting instance ${name}..."
                  incus start "${name}"
                else
                  echo "Instance ${name} is already running"
                fi
              '';
              ExecStop = pkgs.writeShellScript "incus-vm-${name}-stop" ''
                set -euo pipefail
                export PATH="${lib.makeBinPath [pkgs.incus]}:$PATH"

                STATUS=$(incus info "${name}" 2>/dev/null | grep "^Status:" | awk '{print $2}' || echo "Unknown")
                if [ "$STATUS" = "RUNNING" ]; then
                  echo "Stopping instance ${name}..."
                  incus stop "${name}"
                else
                  echo "Instance ${name} is not running (status: $STATUS)"
                fi
              '';
            };
          }
      )
      cfg.instances;
  };
}
