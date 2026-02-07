{
  config,
  pkgs,
  lib,
  ...
}: {
  services.clubcotton.borgmatic = {
    enable = true;
    verbosity = 2;

    # Enable Prometheus metrics
    prometheusExporter.enable = true;

    # Directories to backup
    sourceDirectories = [
      "/var/lib"
      "/backups/postgresql"
      "/media/photos"
      "/media/documents"
      "/media/tomcotton/data"
      "/media/tomcotton/audio-library/SFX_Library/My_Exports"
    ];

    # Snapshot ZFS datasets before backup
    zfs = {
      enable = true;
      datasets = [
        "rpool/local/lib"
        "backuppool/local/postgresql"
        "mediapool/local/documents"
        "mediapool/local/tomcotton/data"
        "mediapool/local/tomcotton/audio-library"
      ];
    };

    # Repository configuration (rsync.net example)
    repositories = [
      {
        path = "ssh://de4729@de4729.rsync.net/./backups-nas-01";
        label = "rsync.net";
      }
    ];

    # Encryption (required for rsync.net)
    encryption = {
      mode = "repokey-blake2"; # Recommended for rsync.net
      passphraseFile = config.age.secrets.borg-passphrase.path;
    };

    # SSH configuration for rsync.net
    # ServerAliveInterval sends keepalive every 60s to prevent connection timeouts
    # ServerAliveCountMax=3 means disconnect after 3 missed keepalives (3 min)
    sshCommand = "ssh -i /var/run/agenix/syncoid-ssh-key -o ServerAliveInterval=60 -o ServerAliveCountMax=3";

    # Borg version on rsync.net
    remotePath = "borg14";

    # Retention policy
    retention = {
      keepDaily = 7;
      keepWeekly = 4;
      keepMonthly = 6;
      keepYearly = 1;
    };

    # Exclude patterns
    excludePatterns = [
      "*.pyc"
      "__pycache__"
      "/var/cache"
      "/var/tmp"
      "*/node_modules"
      "*/.cache"
    ];

    # Disable default checks (we override in extraConfig)
    checks = [];

    # Limit check duration to prevent rsync.net timeouts
    # Repository check resumes where it left off on subsequent runs
    # Archives check limited to last 1 to avoid long-running checks
    extraConfig = {
      checks = [
        {
          name = "repository";
          max_duration = 180; # 3 minutes max
        }
        {
          name = "archives";
          check_last = 1; # Only check the most recent archive
        }
      ];
    };
  };
}
