{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  service = "restic";
  cfg = config.services.clubcotton.${service};

  # Get the source directories for a repository (per-repo or global)
  getRepoPaths = repoName: repoCfg:
    if repoCfg.paths != null
    then repoCfg.paths
    else cfg.sourceDirectories;

  # Get the exclude patterns for a repository (per-repo or global)
  getRepoExclude = repoCfg:
    if repoCfg.exclude != null
    then repoCfg.exclude
    else cfg.excludePatterns;

  # Generate the source paths based on ZFS snapshot mounts or original paths
  getSourcePaths = repoName: repoCfg: let
    sourceDirs = getRepoPaths repoName repoCfg;
  in
    if cfg.zfs.enable
    then
      # Map source directories to their snapshot mount points
      map (
        srcDir: let
          # Find the dataset that matches this source directory
          matchingDataset = findFirst (ds: hasPrefix (cfg.zfs.datasetMountPoints.${ds} or "") srcDir) null cfg.zfs.datasets;
        in
          if matchingDataset != null
          then let
            originalMount = cfg.zfs.datasetMountPoints.${matchingDataset};
            snapshotMount = "${cfg.zfs.snapshotMountPoint}/${repoName}/${matchingDataset}";
          in
            replaceStrings [originalMount] [snapshotMount] srcDir
          else srcDir
      )
      sourceDirs
    else sourceDirs;

  # Script to create ZFS snapshots and mount them
  mkSnapshotScript = repoName: let
    timestamp = "\${TIMESTAMP:-$(date +%Y%m%d-%H%M%S)}";
    snapshotName = "restic-${repoName}-${timestamp}";
    mountBase = "${cfg.zfs.snapshotMountPoint}/${repoName}";
  in
    pkgs.writeShellScript "restic-zfs-snapshot-${repoName}" ''
      set -euo pipefail
      export PATH="${lib.makeBinPath [pkgs.zfs pkgs.util-linux pkgs.coreutils]}:$PATH"

      TIMESTAMP=$(date +%Y%m%d-%H%M%S)
      SNAPSHOT_NAME="restic-${repoName}-''${TIMESTAMP}"

      echo "Creating ZFS snapshots for restic backup: ${repoName}"

      # Create snapshots for each dataset
      ${concatMapStringsSep "\n" (dataset: ''
          echo "Creating snapshot: ${dataset}@''${SNAPSHOT_NAME}"
          zfs snapshot "${dataset}@''${SNAPSHOT_NAME}"
        '')
        cfg.zfs.datasets}

      # Create mount base directory
      mkdir -p "${mountBase}"

      # Mount each snapshot
      ${concatMapStringsSep "\n" (dataset: ''
          MOUNT_POINT="${mountBase}/${dataset}"
          mkdir -p "''${MOUNT_POINT}"
          echo "Mounting ${dataset}@''${SNAPSHOT_NAME} at ''${MOUNT_POINT}"
          mount -t zfs "${dataset}@''${SNAPSHOT_NAME}" "''${MOUNT_POINT}"
        '')
        cfg.zfs.datasets}

      # Store snapshot name for cleanup
      echo "''${SNAPSHOT_NAME}" > "${mountBase}/.snapshot-name"

      echo "ZFS snapshots created and mounted successfully"
    '';

  # Script to unmount and destroy ZFS snapshots
  mkCleanupScript = repoName: let
    mountBase = "${cfg.zfs.snapshotMountPoint}/${repoName}";
  in
    pkgs.writeShellScript "restic-zfs-cleanup-${repoName}" ''
      set -euo pipefail
      export PATH="${lib.makeBinPath [pkgs.zfs pkgs.util-linux pkgs.coreutils]}:$PATH"

      SNAPSHOT_NAME_FILE="${mountBase}/.snapshot-name"

      if [ ! -f "''${SNAPSHOT_NAME_FILE}" ]; then
        echo "No snapshot name file found, nothing to clean up"
        exit 0
      fi

      SNAPSHOT_NAME=$(cat "''${SNAPSHOT_NAME_FILE}")
      echo "Cleaning up ZFS snapshots: ''${SNAPSHOT_NAME}"

      # Unmount each snapshot (in reverse order for nested mounts)
      ${concatMapStringsSep "\n" (dataset: ''
        MOUNT_POINT="${mountBase}/${dataset}"
        if mountpoint -q "''${MOUNT_POINT}" 2>/dev/null; then
          echo "Unmounting ''${MOUNT_POINT}"
          umount "''${MOUNT_POINT}" || echo "Warning: failed to unmount ''${MOUNT_POINT}"
        fi
      '') (reverseList cfg.zfs.datasets)}

      # Destroy the snapshots
      ${concatMapStringsSep "\n" (dataset: ''
          if zfs list -t snapshot "${dataset}@''${SNAPSHOT_NAME}" >/dev/null 2>&1; then
            echo "Destroying snapshot: ${dataset}@''${SNAPSHOT_NAME}"
            zfs destroy "${dataset}@''${SNAPSHOT_NAME}" || echo "Warning: failed to destroy ${dataset}@''${SNAPSHOT_NAME}"
          fi
        '')
        cfg.zfs.datasets}

      # Clean up mount directories and snapshot name file
      rm -f "''${SNAPSHOT_NAME_FILE}"

      echo "ZFS snapshot cleanup completed"
    '';

  # Helper to build retention options
  mkRetentionArgs = retention:
    optionals (retention.keepDaily != null) ["--keep-daily" (toString retention.keepDaily)]
    ++ optionals (retention.keepWeekly != null) ["--keep-weekly" (toString retention.keepWeekly)]
    ++ optionals (retention.keepMonthly != null) ["--keep-monthly" (toString retention.keepMonthly)]
    ++ optionals (retention.keepYearly != null) ["--keep-yearly" (toString retention.keepYearly)]
    ++ optionals (retention.keepWithin != null) ["--keep-within" retention.keepWithin];

  retentionSubmodule = {
    options = {
      keepDaily = mkOption {
        type = types.nullOr types.int;
        default = 7;
        description = "Number of daily snapshots to keep";
      };
      keepWeekly = mkOption {
        type = types.nullOr types.int;
        default = 4;
        description = "Number of weekly snapshots to keep";
      };
      keepMonthly = mkOption {
        type = types.nullOr types.int;
        default = 6;
        description = "Number of monthly snapshots to keep";
      };
      keepYearly = mkOption {
        type = types.nullOr types.int;
        default = 1;
        description = "Number of yearly snapshots to keep";
      };
      keepWithin = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Keep all snapshots within this duration (e.g., '2m' for 2 months)";
        example = "2m";
      };
    };
  };

  repositorySubmodule = {name, ...}: {
    options = {
      repository = mkOption {
        type = types.str;
        description = ''
          Repository URL. Supports various backends:
          - Local: /path/to/repo
          - SFTP: sftp:user@host:/path
          - S3: s3:s3.amazonaws.com/bucket
          - B2: b2:bucket-name
          - Rest: rest:http://host:port/
        '';
        example = "sftp:user@host.rsync.net:restic-backup";
      };

      paths = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = ''
          Directories to backup for this repository.
          If null, uses the global sourceDirectories.
        '';
        example = ["/var/lib" "/home"];
      };

      exclude = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = ''
          Patterns to exclude for this repository.
          If null, uses the global excludePatterns.
        '';
        example = ["*.pyc" "/var/cache"];
      };

      passwordFile = mkOption {
        type = types.path;
        description = "Path to file containing repository encryption password";
      };

      environmentFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to file containing environment variables for the repository
          (e.g., B2_ACCOUNT_ID, B2_ACCOUNT_KEY, AWS_ACCESS_KEY_ID, etc.)
        '';
      };

      timerConfig = mkOption {
        type = types.attrsOf types.str;
        default = {
          OnCalendar = "daily";
          Persistent = "true";
        };
        description = "Systemd timer configuration";
        example = {
          OnCalendar = "06:00";
          Persistent = "true";
          RandomizedDelaySec = "1h";
        };
      };

      retention = mkOption {
        type = types.submodule retentionSubmodule;
        default = {};
        description = "Retention policy for this repository";
      };

      extraBackupArgs = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Extra arguments to pass to restic backup";
        example = ["--exclude-caches" "--one-file-system"];
      };

      extraOptions = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Extra options for restic (passed via -o flag)";
        example = ["sftp.command='ssh user@host -i /path/to/key -s sftp'"];
      };

      initialize = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to automatically initialize the repository if it doesn't exist";
      };

      runCheck = mkOption {
        type = types.bool;
        default = false;
        description = "Run restic check after backup";
      };

      checkOpts = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Options passed to restic check";
        example = ["--read-data-subset=10%"];
      };

      pruneOpts = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional options for restic forget/prune";
      };
    };
  };
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "restic backup service";

    sourceDirectories = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Directories to backup";
      example = ["/var/lib" "/home" "/etc"];
    };

    excludePatterns = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Patterns to exclude from backup (passed to --exclude)";
      example = ["*.pyc" "/var/cache" "*/.cache"];
    };

    repositories = mkOption {
      type = types.attrsOf (types.submodule repositorySubmodule);
      default = {};
      description = "Repository configurations. Each repository runs independently.";
    };

    sshCommand = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        SSH command to use for SFTP repositories.
        Useful for specifying identity files or connection options.
      '';
      example = "ssh -i /var/run/agenix/syncoid-ssh-key -o ServerAliveInterval=60 -o ServerAliveCountMax=3";
    };

    zfs = {
      enable = mkEnableOption "ZFS snapshot support";

      datasets = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "ZFS datasets to snapshot before backup";
        example = ["rpool/local/lib" "mediapool/local/documents"];
      };

      snapshotMountPoint = mkOption {
        type = types.str;
        default = "/mnt/.restic-snapshots";
        description = "Base directory for mounting ZFS snapshots";
      };

      datasetMountPoints = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = ''
          Mapping of dataset names to their normal mount points.
          This is used to translate source directories to snapshot paths.
        '';
        example = {
          "rpool/local/lib" = "/var/lib";
          "mediapool/local/documents" = "/media/documents";
        };
      };
    };

    prometheusExporter = {
      enable = mkEnableOption "Prometheus metrics for restic backups";

      port = mkOption {
        type = types.port;
        default = 9997;
        description = "Port for the Prometheus exporter to listen on";
      };

      refreshInterval = mkOption {
        type = types.int;
        default = 300;
        description = "Interval in seconds between metrics refresh";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.repositories != {};
        message = "services.clubcotton.restic.repositories must have at least one repository configured";
      }
      {
        # Either global sourceDirectories or all repos have their own paths
        assertion = cfg.sourceDirectories != [] || all (repo: repo.paths != null && repo.paths != []) (attrValues cfg.repositories);
        message = "services.clubcotton.restic: Either sourceDirectories must be set or all repositories must have paths defined";
      }
      {
        assertion = !cfg.zfs.enable || cfg.zfs.datasets != [];
        message = "services.clubcotton.restic.zfs.datasets must be set when ZFS is enabled";
      }
      {
        assertion = !cfg.zfs.enable || cfg.zfs.datasetMountPoints != {};
        message = "services.clubcotton.restic.zfs.datasetMountPoints must be configured when ZFS is enabled";
      }
    ];

    # Use the NixOS restic module for each repository
    services.restic.backups =
      mapAttrs (name: repoCfg: {
        inherit (repoCfg) repository passwordFile initialize;

        paths = getSourcePaths name repoCfg;

        exclude = getRepoExclude repoCfg;

        extraBackupArgs =
          repoCfg.extraBackupArgs
          ++ optionals (cfg.sshCommand != null && hasPrefix "sftp:" repoCfg.repository) [
            "-o"
            "sftp.command='${cfg.sshCommand} -s sftp'"
          ];

        extraOptions = repoCfg.extraOptions;

        timerConfig = repoCfg.timerConfig;

        pruneOpts =
          (mkRetentionArgs repoCfg.retention)
          ++ repoCfg.pruneOpts;

        checkOpts = repoCfg.checkOpts;
        runCheck = repoCfg.runCheck;

        # Set backup job hooks for ZFS snapshots
        backupPrepareCommand = mkIf cfg.zfs.enable (toString (mkSnapshotScript name));
        backupCleanupCommand = mkIf cfg.zfs.enable (toString (mkCleanupScript name));

        # Environment file for cloud credentials
        environmentFile = repoCfg.environmentFile;
      })
      cfg.repositories;

    # Override systemd service settings for ZFS access and add prometheus exporter
    systemd.services = mkMerge [
      (mapAttrs' (name: _:
        nameValuePair "restic-backups-${name}" {
          path = mkIf cfg.zfs.enable [
            pkgs.zfs
            pkgs.util-linux
          ];

          serviceConfig = mkIf cfg.zfs.enable {
            # Disable security restrictions that prevent ZFS access
            PrivateDevices = mkForce false;
            PrivateTmp = mkForce false;
            ProtectSystem = mkForce false;
            ProtectHome = mkForce false;
            CapabilityBoundingSet = mkForce "CAP_DAC_READ_SEARCH CAP_NET_RAW CAP_SYS_ADMIN CAP_SYS_RESOURCE CAP_FOWNER CAP_CHOWN CAP_DAC_OVERRIDE";
            DevicePolicy = mkForce "auto";
            SystemCallFilter = mkForce "";
            SystemCallArchitectures = mkForce "";
            RestrictNamespaces = mkForce false;
            ProtectKernelTunables = mkForce false;
            ProtectControlGroups = mkForce false;
            NoNewPrivileges = mkForce false;
          };
        })
      cfg.repositories)

      # Prometheus exporter for restic
      # Note: NixOS doesn't have a built-in restic exporter, so we create a simple
      # metrics script that can be scraped via the textfile collector or a custom service
      (mkIf cfg.prometheusExporter.enable {
        restic-metrics = {
          description = "Restic backup metrics exporter";
          after = ["network.target"];
          wantedBy = ["multi-user.target"];

          path = [pkgs.restic pkgs.coreutils pkgs.gawk];

          environment = {
            RESTIC_METRICS_PORT = toString cfg.prometheusExporter.port;
          };

          serviceConfig = {
            Type = "simple";
            DynamicUser = false;
            User = "root";
            Group = "root";
            Restart = "always";
            RestartSec = "10s";
          };

          script = let
            repoConfigs =
              mapAttrsToList (name: repoCfg: {
                inherit name;
                inherit (repoCfg) repository passwordFile environmentFile;
              })
              cfg.repositories;

            repoMetricsScript = repo: ''
              # Metrics for repository: ${repo.name}
              REPO_NAME="${repo.name}"
              export RESTIC_REPOSITORY="${repo.repository}"
              export RESTIC_PASSWORD_FILE="${repo.passwordFile}"
              ${optionalString (repo.environmentFile != null) "source ${repo.environmentFile}"}
              ${
                optionalString (cfg.sshCommand != null && hasPrefix "sftp:" repo.repository)
                ''export RESTIC_REPOSITORY_FILE="" && RESTIC_OPTS="-o sftp.command='${cfg.sshCommand} -s sftp'"''
              }

              # Get latest snapshot info
              if SNAPSHOTS=$(restic snapshots --json ''${RESTIC_OPTS:-} 2>/dev/null); then
                SNAPSHOT_COUNT=$(echo "$SNAPSHOTS" | ${pkgs.jq}/bin/jq 'length')
                if [ "$SNAPSHOT_COUNT" -gt 0 ]; then
                  LATEST_TIME=$(echo "$SNAPSHOTS" | ${pkgs.jq}/bin/jq -r '.[-1].time')
                  LATEST_TIMESTAMP=$(date -d "$LATEST_TIME" +%s 2>/dev/null || echo "0")
                  echo "restic_snapshot_count{repository=\"$REPO_NAME\"} $SNAPSHOT_COUNT"
                  echo "restic_latest_snapshot_timestamp{repository=\"$REPO_NAME\"} $LATEST_TIMESTAMP"
                  echo "restic_backup_success{repository=\"$REPO_NAME\"} 1"
                else
                  echo "restic_snapshot_count{repository=\"$REPO_NAME\"} 0"
                  echo "restic_backup_success{repository=\"$REPO_NAME\"} 0"
                fi

                # Get stats for latest snapshot
                if STATS=$(restic stats --json ''${RESTIC_OPTS:-} 2>/dev/null); then
                  TOTAL_SIZE=$(echo "$STATS" | ${pkgs.jq}/bin/jq '.total_size // 0')
                  TOTAL_FILE_COUNT=$(echo "$STATS" | ${pkgs.jq}/bin/jq '.total_file_count // 0')
                  echo "restic_total_size_bytes{repository=\"$REPO_NAME\"} $TOTAL_SIZE"
                  echo "restic_total_file_count{repository=\"$REPO_NAME\"} $TOTAL_FILE_COUNT"
                fi
              else
                echo "restic_backup_success{repository=\"$REPO_NAME\"} 0"
                echo "restic_repository_available{repository=\"$REPO_NAME\"} 0"
              fi
            '';
          in ''
            set +e  # Don't exit on errors - we want to continue even if one repo fails

            while true; do
              {
                echo "# HELP restic_snapshot_count Number of snapshots in repository"
                echo "# TYPE restic_snapshot_count gauge"
                echo "# HELP restic_latest_snapshot_timestamp Unix timestamp of latest snapshot"
                echo "# TYPE restic_latest_snapshot_timestamp gauge"
                echo "# HELP restic_backup_success Whether the last backup operation succeeded"
                echo "# TYPE restic_backup_success gauge"
                echo "# HELP restic_total_size_bytes Total size of backups in bytes"
                echo "# TYPE restic_total_size_bytes gauge"
                echo "# HELP restic_total_file_count Total number of files in backups"
                echo "# TYPE restic_total_file_count gauge"
                echo "# HELP restic_repository_available Whether the repository is reachable"
                echo "# TYPE restic_repository_available gauge"
                echo ""

                ${concatMapStringsSep "\n" repoMetricsScript repoConfigs}
              } > /tmp/restic_metrics.prom.tmp
              mv /tmp/restic_metrics.prom.tmp /tmp/restic_metrics.prom

              sleep ${toString cfg.prometheusExporter.refreshInterval}
            done
          '';
        };

        # Serve the metrics file via a simple HTTP server
        restic-metrics-http = {
          description = "HTTP server for restic metrics";
          after = ["network.target" "restic-metrics.service"];
          wantedBy = ["multi-user.target"];

          serviceConfig = {
            Type = "simple";
            DynamicUser = true;
            Restart = "always";
            RestartSec = "5s";
          };

          script = ''
            ${pkgs.python3}/bin/python3 -c '
            import http.server
            import socketserver
            import os

            PORT = ${toString cfg.prometheusExporter.port}

            class MetricsHandler(http.server.BaseHTTPRequestHandler):
                def do_GET(self):
                    if self.path == "/metrics":
                        try:
                            with open("/tmp/restic_metrics.prom", "r") as f:
                                content = f.read()
                            self.send_response(200)
                            self.send_header("Content-type", "text/plain; charset=utf-8")
                            self.end_headers()
                            self.wfile.write(content.encode())
                        except FileNotFoundError:
                            self.send_response(503)
                            self.send_header("Content-type", "text/plain")
                            self.end_headers()
                            self.wfile.write(b"Metrics not yet available")
                    else:
                        self.send_response(404)
                        self.end_headers()

                def log_message(self, format, *args):
                    pass  # Suppress logging

            with socketserver.TCPServer(("", PORT), MetricsHandler) as httpd:
                httpd.serve_forever()
            '
          '';
        };
      })
    ];

    # Ensure snapshot mount point exists
    systemd.tmpfiles.rules = mkIf cfg.zfs.enable [
      "d ${cfg.zfs.snapshotMountPoint} 0755 root root - -"
    ];
  };
}
