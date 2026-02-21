{
  config,
  lib,
  pkgs,
  self,
  ...
}:
with lib; let
  cfg = config.services.incus-cluster;

  # Filter instances to only those for this site
  siteInstances = cfg.instances;

  incusBin = lib.getExe' pkgs.incus "incus";
  jqBin = lib.getExe pkgs.jq;

  # Build image-related paths for NixOS instances (deploy = "image")
  nixosImageInfo = name: instanceCfg: let
    guestConfig = self.nixosConfigurations.${instanceCfg.configuration};
    isVM = instanceCfg.type == "vm";
  in {
    imageAlias = "nixos-${instanceCfg.configuration}";
    # VM: QCOW2 file; Container: squashfs directory (must glob for .squashfs file)
    imagePath =
      if isVM
      then "${guestConfig.config.system.build.qemuImage}/nixos.qcow2"
      else "${guestConfig.config.system.build.squashfs}";
    imageIsDir = !isVM; # squashfs output is a directory containing the .squashfs file
    metadataDir = "${guestConfig.config.system.build.metadata}/tarball";
  };

  # Build launch flags for an instance
  # NOTE: -d flags can only override devices already in the profile.
  # Network and extra devices are added post-launch via incus config device add.
  mkLaunchFlags = name: instanceCfg: let
    isVM = instanceCfg.type == "vm";
    extraConfigFlags = concatLists (mapAttrsToList (k: v: ["-c" "${k}=${v}"]) instanceCfg.extraConfig);
  in
    (optional isVM "--vm")
    ++ ["-p" instanceCfg.profile]
    ++ (optionals (instanceCfg.target != null) ["--target" instanceCfg.target])
    ++ extraConfigFlags;

  # Generate network device setup commands (run after instance creation)
  mkNetworkSetup = name: instanceCfg: let
    nictype = instanceCfg.network.mode;
    parent = instanceCfg.network.parent;
    hwaddr = instanceCfg.network.hwaddr;
  in ''
    # Set up network device eth0
    if ! incus config device get "$INSTANCE_NAME" eth0 type &>/dev/null 2>&1; then
      echo "Adding network device eth0 (${nictype}, parent=${parent})"
      incus config device add "$INSTANCE_NAME" eth0 nic \
        nictype="${nictype}" \
        parent="${parent}" \
        ${optionalString (hwaddr != null) "hwaddr=\"${hwaddr}\""}
    else
      echo "Network device eth0 already exists on $INSTANCE_NAME"
    fi
  '';

  # Generate the ExecStartPre script for an instance
  mkStartPreScript = name: instanceCfg: let
    isOpaque = instanceCfg.deploy == "opaque";
    isImage = instanceCfg.deploy == "image";
    imageInfo =
      if isImage
      then nixosImageInfo name instanceCfg
      else null;
    imageAlias =
      if isImage
      then imageInfo.imageAlias
      else instanceCfg.imageAlias;
    launchFlags = concatStringsSep " " (map escapeShellArg (mkLaunchFlags name instanceCfg));
  in
    pkgs.writeShellScript "incus-instance-${name}-pre" ''
      set -euo pipefail
      export PATH="${lib.makeBinPath [pkgs.incus pkgs.coreutils pkgs.jq]}:$PATH"

      INSTANCE_NAME="${name}"
      IMAGE_ALIAS="${imageAlias}"

      # Check if instance already exists (adopt-not-recreate pattern)
      if incus info "$INSTANCE_NAME" &>/dev/null; then
        echo "Instance $INSTANCE_NAME already exists, skipping creation"
      else
        echo "Instance $INSTANCE_NAME does not exist, creating..."

        ${
        if isImage
        then ''
          # Import NixOS image built from nixosConfigurations
          METADATA_FILE=("${imageInfo.metadataDir}/"*.tar.xz)
          if [ ! -f "''${METADATA_FILE[0]}" ]; then
            echo "ERROR: No metadata tarball found in ${imageInfo.metadataDir}/"
            exit 1
          fi

          # Find the image file (squashfs output is a directory)
          ${
            if imageInfo.imageIsDir
            then ''
              IMAGE_FILE=("${imageInfo.imagePath}/"*.squashfs)
              if [ ! -f "''${IMAGE_FILE[0]}" ]; then
                echo "ERROR: No squashfs file found in ${imageInfo.imagePath}/"
                exit 1
              fi
            ''
            else ''
              IMAGE_FILE=("${imageInfo.imagePath}")
            ''
          }

          # Check if image already exists with this alias
          if incus image info "$IMAGE_ALIAS" &>/dev/null; then
            echo "Image $IMAGE_ALIAS already exists, skipping import"
          else
            # Delete old image if it exists under a different alias but same fingerprint
            incus image delete "$IMAGE_ALIAS" 2>/dev/null || true
            echo "Importing image as $IMAGE_ALIAS..."
            incus image import "''${METADATA_FILE[0]}" "''${IMAGE_FILE[0]}" --alias "$IMAGE_ALIAS"
          fi
        ''
        else if isOpaque
        then ''
          # Import opaque image from provided paths
          ${optionalString (instanceCfg.imagePath != null && instanceCfg.metadataPath != null) ''
            if ! incus image alias list --format json | jq -e '.[] | select(.name == "'"$IMAGE_ALIAS"'")' &>/dev/null; then
              echo "Importing opaque image as $IMAGE_ALIAS..."
              incus image import "${instanceCfg.metadataPath}" "${instanceCfg.imagePath}" --alias "$IMAGE_ALIAS"
            else
              echo "Image alias $IMAGE_ALIAS already exists, skipping import"
            fi
          ''}
        ''
        else ''
          echo "ERROR: Unknown deploy strategy for $INSTANCE_NAME"
          exit 1
        ''
      }

        echo "Launching instance $INSTANCE_NAME from $IMAGE_ALIAS..."
        incus launch "$IMAGE_ALIAS" "$INSTANCE_NAME" ${launchFlags}

        # Signal ExecStart to skip (instance was just started by launch)
        touch "/run/incus-instance-${name}.launched"
      fi

      # Reconcile network device (runs on every invocation, including adoption)
      ${mkNetworkSetup name instanceCfg}

      ${optionalString (instanceCfg.storagePool != null) ''
        # Reconcile root disk storage pool
        CURRENT_POOL=$(incus config device get "$INSTANCE_NAME" root pool 2>/dev/null || echo "")
        if [ "$CURRENT_POOL" != "${instanceCfg.storagePool}" ]; then
          echo "Setting root disk pool to ${instanceCfg.storagePool}"
          incus config device set "$INSTANCE_NAME" root pool="${instanceCfg.storagePool}" 2>/dev/null || \
            incus config device add "$INSTANCE_NAME" root disk pool="${instanceCfg.storagePool}" path="/" 2>/dev/null || true
        fi
      ''}

      # Reconcile extra devices
      ${concatStringsSep "\n" (mapAttrsToList (
          devName: devCfg: let
            propsStr = concatStringsSep " " (mapAttrsToList (k: v: "${k}=${v}") devCfg.properties);
          in ''
            if ! incus config device get "$INSTANCE_NAME" "${devName}" type &>/dev/null 2>&1; then
              echo "Adding device ${devName} (${devCfg.type})"
              incus config device add "$INSTANCE_NAME" "${devName}" "${devCfg.type}" ${propsStr}
            else
              echo "Device ${devName} already exists on $INSTANCE_NAME"
            fi
          ''
        )
        instanceCfg.devices)}
    '';

  # Generate the ExecStart script
  mkStartScript = name: instanceCfg:
    pkgs.writeShellScript "incus-instance-${name}-start" ''
      set -euo pipefail
      export PATH="${lib.makeBinPath [pkgs.incus pkgs.coreutils pkgs.gawk pkgs.gnugrep]}:$PATH"

      INSTANCE_NAME="${name}"

      # If just launched by ExecStartPre, skip start
      if [ -f "/run/incus-instance-${name}.launched" ]; then
        rm -f "/run/incus-instance-${name}.launched"
        echo "Instance $INSTANCE_NAME already started by launch"
        exit 0
      fi

      # Start if not already running
      STATUS=$(incus info "$INSTANCE_NAME" 2>/dev/null | grep "^Status:" | awk '{print $2}' || echo "Unknown")
      if [ "$STATUS" != "RUNNING" ]; then
        echo "Starting instance $INSTANCE_NAME..."
        incus start "$INSTANCE_NAME"
      else
        echo "Instance $INSTANCE_NAME is already running"
      fi
    '';

  # Generate the ExecStop script
  mkStopScript = name: instanceCfg:
    pkgs.writeShellScript "incus-instance-${name}-stop" ''
      set -euo pipefail
      export PATH="${lib.makeBinPath [pkgs.incus pkgs.coreutils pkgs.gawk pkgs.gnugrep]}:$PATH"

      INSTANCE_NAME="${name}"

      STATUS=$(incus info "$INSTANCE_NAME" 2>/dev/null | grep "^Status:" | awk '{print $2}' || echo "Unknown")
      if [ "$STATUS" = "RUNNING" ]; then
        echo "Stopping instance $INSTANCE_NAME..."
        incus stop "$INSTANCE_NAME" --timeout 60
      else
        echo "Instance $INSTANCE_NAME is not running (status: $STATUS)"
      fi
    '';
in {
  config = mkIf (cfg.enable && siteInstances != {}) {
    systemd.services =
      mapAttrs' (
        name: instanceCfg:
          nameValuePair "incus-instance-${name}" {
            description = "Incus ${instanceCfg.type}: ${name}";
            after = ["incus.service" "incus-preseed.service"];
            requires = ["incus.service"];
            wantedBy = optional instanceCfg.autostart "multi-user.target";

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              TimeoutStartSec = "10min";
              ExecStartPre = "${mkStartPreScript name instanceCfg}";
              ExecStart = "${mkStartScript name instanceCfg}";
              ExecStop = "${mkStopScript name instanceCfg}";
            };
          }
      )
      siteInstances;
  };
}
