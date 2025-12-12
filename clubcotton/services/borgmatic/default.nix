{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  service = "borgmatic";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service} backup service";
    };

    sourceDirectories = lib.mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        List of source directories and files to backup. Globs and tildes are expanded.
      '';
      example = [
        "/var/lib"
        "/home"
        "/etc"
      ];
    };

    repositories = lib.mkOption {
      type = types.listOf (types.submodule {
        options = {
          path = lib.mkOption {
            type = types.str;
            description = "Path to the repository (local or remote SSH path)";
            example = "ssh://username@server.rsync.net/./backups/hostname";
          };
          label = lib.mkOption {
            type = types.str;
            description = "Label for the repository";
            example = "rsync.net";
          };
        };
      });
      default = [];
      description = ''
        List of borg repositories to backup to. For rsync.net, use SSH paths.
      '';
      example = [
        {
          path = "ssh://username@server.rsync.net/./backups/hostname";
          label = "rsync.net";
        }
      ];
    };

    encryption = {
      mode = lib.mkOption {
        type = types.enum [
          "repokey"
          "keyfile"
          "repokey-blake2"
          "keyfile-blake2"
          "authenticated"
          "authenticated-blake2"
          "none"
        ];
        default = "repokey-blake2";
        description = ''
          Encryption mode for the repository. repokey modes store the key in the repository.
          keyfile modes store the key locally. blake2 variants use faster BLAKE2b hashing.
        '';
      };

      passphraseFile = lib.mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to file containing the encryption passphrase.
          Required for all encryption modes except "none".
        '';
      };
    };

    retention = {
      keepDaily = lib.mkOption {
        type = types.nullOr types.int;
        default = 7;
        description = "Number of daily archives to keep";
      };

      keepWeekly = lib.mkOption {
        type = types.nullOr types.int;
        default = 4;
        description = "Number of weekly archives to keep";
      };

      keepMonthly = lib.mkOption {
        type = types.nullOr types.int;
        default = 6;
        description = "Number of monthly archives to keep";
      };

      keepYearly = lib.mkOption {
        type = types.nullOr types.int;
        default = 1;
        description = "Number of yearly archives to keep";
      };
    };

    compression = lib.mkOption {
      type = types.str;
      default = "auto,zstd";
      description = ''
        Compression algorithm to use. "auto,zstd" is recommended for good compression
        and speed. Other options: "lz4", "zlib,6", "lzma,6", "none".
      '';
      example = "auto,zstd";
    };

    excludePatterns = lib.mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        Patterns to exclude from backup. Supports shell-style wildcards.
      '';
      example = [
        "*.pyc"
        "/home/*/.cache"
        "/var/cache"
        "/var/tmp"
      ];
    };

    excludeCaches = lib.mkOption {
      type = types.bool;
      default = true;
      description = ''
        Exclude directories that contain a CACHEDIR.TAG file.
      '';
    };

    oneFileSystem = lib.mkOption {
      type = types.bool;
      default = false;
      description = ''
        Stay in same file system and do not cross mount points.
      '';
    };

    archiveNameFormat = lib.mkOption {
      type = types.str;
      default = "{hostname}-{now:%Y-%m-%dT%H:%M:%S}";
      description = ''
        Format string for archive names. Available placeholders:
        {hostname}, {user}, {now}, {utcnow}, {fqdn}
      '';
    };

    sshCommand = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        SSH command to use for remote repositories. Useful for specifying
        identity files, ports, or other SSH options.
      '';
      example = "ssh -i /root/.ssh/id_ed25519_rsyncnet -p 22";
    };

    remotePath = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Path to the borg executable on the remote server. Required for some
        hosting providers like rsync.net that have multiple borg versions.
      '';
      example = "borg14";
    };

    checks = lib.mkOption {
      type = types.listOf (types.enum [
        "repository"
        "archives"
        "data"
        "extract"
      ]);
      default = ["repository" "archives"];
      description = ''
        Consistency checks to run. "repository" checks repo integrity,
        "archives" checks archive metadata, "data" verifies archive data,
        "extract" does a test extraction.
      '';
    };

    checkLast = lib.mkOption {
      type = types.nullOr types.int;
      default = 3;
      description = ''
        Number of most recent archives to check. null means check all archives.
      '';
    };

    beforeBackupHooks = lib.mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        Shell commands to run before creating a backup.
      '';
      example = [
        "echo 'Starting backup'"
        "systemctl stop myservice"
      ];
    };

    afterBackupHooks = lib.mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        Shell commands to run after creating a backup.
      '';
      example = [
        "systemctl start myservice"
        "echo 'Backup complete'"
      ];
    };

    onErrorHooks = lib.mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        Shell commands to run if an error occurs during backup.
      '';
      example = [
        "echo 'Backup failed!' | mail -s 'Backup Error' admin@example.com"
      ];
    };

    postgresqlDatabases = lib.mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = lib.mkOption {
            type = types.str;
            description = "Database name or 'all' for all databases";
          };
          hostname = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Database hostname";
          };
          port = lib.mkOption {
            type = types.nullOr types.port;
            default = null;
            description = "Database port";
          };
          username = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Database username";
          };
          password = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Database password";
          };
          format = lib.mkOption {
            type = types.nullOr (types.enum ["plain" "custom" "directory" "tar"]);
            default = null;
            description = "Dump format";
          };
        };
      });
      default = [];
      description = ''
        List of PostgreSQL databases to backup.
      '';
    };

    zfs = {
      enable =
        lib.mkEnableOption "ZFS snapshot support"
        // {
          description = ''
            Enable ZFS filesystem snapshot support. Borgmatic will automatically
            discover and snapshot ZFS datasets based on your source_directories.
            You can also set the user property org.torsion.borgmatic:backup=auto
            on datasets you want backed up.
          '';
        };

      datasets = lib.mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          List of ZFS datasets to automatically mark for borgmatic backup.
          This sets the user property org.torsion.borgmatic:backup=auto on each dataset.
        '';
        example = [
          "rpool/local/lib"
          "rpool/safe/home"
        ];
      };

      zfsCommand = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Command to use instead of 'zfs'";
        example = "/usr/local/bin/zfs";
      };

      mountCommand = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Command to use instead of 'mount'";
        example = "/usr/local/bin/mount";
      };

      umountCommand = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Command to use instead of 'umount'";
        example = "/usr/local/bin/umount";
      };
    };

    extraConfig = lib.mkOption {
      type = types.attrs;
      default = {};
      description = ''
        Additional borgmatic configuration options as an attribute set.
        See https://torsion.org/borgmatic/docs/reference/configuration/
      '';
    };

    verbosity = lib.mkOption {
      type = types.enum [(-2) (-1) 0 1 2];
      default = 0;
      description = ''
        Borgmatic verbosity level. Higher values mean more verbose output.
        -2: Only show critical errors
        -1: Only show errors
         0: Normal output (default)
         1: Info output (use -v)
         2: Debug output (use -vv)
      '';
    };

    prometheusExporter = {
      enable = lib.mkEnableOption "Prometheus exporter for borgmatic";

      port = lib.mkOption {
        type = types.port;
        default = 9996;
        description = "Port for the Prometheus exporter to listen on";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.repositories != [];
        message = "services.clubcotton.borgmatic.repositories must not be empty";
      }
      {
        assertion = cfg.sourceDirectories != [] || cfg.postgresqlDatabases != [];
        message = "services.clubcotton.borgmatic.sourceDirectories or postgresqlDatabases must be configured";
      }
      {
        assertion = cfg.encryption.mode != "none" -> cfg.encryption.passphraseFile != null;
        message = "services.clubcotton.borgmatic.encryption.passphraseFile must be set when encryption is enabled";
      }
    ];

    services.borgmatic = {
      enable = true;
      settings = mkMerge [
        {
          source_directories = cfg.sourceDirectories;
          repositories =
            map (repo: {
              path = repo.path;
              label = repo.label;
            })
            cfg.repositories;

          compression = cfg.compression;
          exclude_patterns = cfg.excludePatterns;
          exclude_caches = cfg.excludeCaches;
          one_file_system = cfg.oneFileSystem;
          archive_name_format = cfg.archiveNameFormat;

          encryption_passcommand =
            mkIf (cfg.encryption.passphraseFile != null)
            "${pkgs.coreutils}/bin/cat ${cfg.encryption.passphraseFile}";

          ssh_command = mkIf (cfg.sshCommand != null) cfg.sshCommand;
          remote_path = mkIf (cfg.remotePath != null) cfg.remotePath;

          keep_daily = mkIf (cfg.retention.keepDaily != null) cfg.retention.keepDaily;
          keep_weekly = mkIf (cfg.retention.keepWeekly != null) cfg.retention.keepWeekly;
          keep_monthly = mkIf (cfg.retention.keepMonthly != null) cfg.retention.keepMonthly;
          keep_yearly = mkIf (cfg.retention.keepYearly != null) cfg.retention.keepYearly;

          checks = map (check: {name = check;}) cfg.checks;
          check_last = mkIf (cfg.checkLast != null) cfg.checkLast;

          before_backup = mkIf (cfg.beforeBackupHooks != []) cfg.beforeBackupHooks;
          after_backup = mkIf (cfg.afterBackupHooks != []) cfg.afterBackupHooks;
          on_error = mkIf (cfg.onErrorHooks != []) cfg.onErrorHooks;

          postgresql_databases =
            mkIf (cfg.postgresqlDatabases != [])
            (map (db: (filterAttrs (n: v: v != null) {
                name = db.name;
                hostname = db.hostname;
                port = db.port;
                username = db.username;
                password = db.password;
                format = db.format;
              }))
              cfg.postgresqlDatabases);

          zfs =
            mkIf cfg.zfs.enable
            (filterAttrs (n: v: v != null) {
              zfs_command = cfg.zfs.zfsCommand;
              mount_command = cfg.zfs.mountCommand;
              umount_command = cfg.zfs.umountCommand;
            });
        }
        cfg.extraConfig
      ];
    };

    # Set ZFS properties for datasets marked for backup
    systemd.services.borgmatic-zfs-setup = lib.mkIf (cfg.zfs.enable && cfg.zfs.datasets != []) {
      description = "Set ZFS user properties for borgmatic backup";
      before = ["borgmatic.service"];
      wantedBy = ["borgmatic.service"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = let
        zfsCmd =
          if cfg.zfs.zfsCommand != null
          then cfg.zfs.zfsCommand
          else "${pkgs.zfs}/bin/zfs";
        setPropertyCommands =
          map (
            dataset: "${zfsCmd} set org.torsion.borgmatic:backup=auto ${dataset}"
          )
          cfg.zfs.datasets;
      in
        lib.concatStringsSep "\n" setPropertyCommands;

      path = [pkgs.zfs];
    };

    # Clear the LoadCredentialEncrypted directive from upstream service
    # since we're using agenix secrets instead
    systemd.services.borgmatic = {
      serviceConfig =
        {
          LoadCredentialEncrypted = lib.mkForce "";
          # Override ExecStart to add verbosity flag
          ExecStart = lib.mkForce (
            let
              verbosityFlag =
                if cfg.verbosity != 0
                then "--verbosity ${toString cfg.verbosity}"
                else "";
            in "${pkgs.systemd}/bin/systemd-inhibit --who=\"borgmatic\" --what=\"sleep:shutdown\" --why=\"Prevent interrupting scheduled backup\" ${pkgs.borgmatic}/bin/borgmatic ${verbosityFlag} --syslog-verbosity 1"
          );
        }
        // lib.optionalAttrs cfg.zfs.enable {
          # Disable security restrictions that prevent ZFS access
          # See: https://torsion.org/borgmatic/reference/configuration/data-sources/zfs/#systemd-settings
          PrivateDevices = lib.mkForce false;
          # May need to adjust capabilities for ZFS operations
          CapabilityBoundingSet = lib.mkForce "CAP_DAC_READ_SEARCH CAP_NET_RAW CAP_SYS_ADMIN";
        };
    };

    systemd.services.borgmatic.path = lib.mkIf cfg.zfs.enable [
      pkgs.zfs
      pkgs.util-linux
    ];

    # Enable Prometheus exporter if requested
    services.prometheus.exporters.borgmatic = lib.mkIf cfg.prometheusExporter.enable {
      enable = true;
      port = cfg.prometheusExporter.port;
      configFile = "/etc/borgmatic/config.yaml";
    };

    # Ensure the exporter runs as root (required to access borgmatic state)
    systemd.services.prometheus-borgmatic-exporter = lib.mkIf cfg.prometheusExporter.enable {
      serviceConfig = {
        User = lib.mkForce "root";
        Group = lib.mkForce "root";
      };
    };
  };
}
