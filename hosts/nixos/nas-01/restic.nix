# Restic backup configuration for nas-01
#
# To enable restic backups:
# 1. Create restic-password.age: agenix -e restic-password.age
#    (Add your repository encryption password - can be shared across repos)
# 2. Set enable = true below
# 3. Initialize rsync.net repo manually or let the service auto-init
#
# To enable B2 backup (optional secondary):
# 1. Create restic-b2-env.age: agenix -e restic-b2-env.age
#    (Contents: B2_ACCOUNT_ID=xxx\nB2_ACCOUNT_KEY=xxx)
# 2. Create B2 bucket: nas-01-restic-backup
# 3. Uncomment the b2 repository section below
{config, ...}: {
  # Configure SSH for rsync.net so restic init/check commands work
  # (The -o sftp.command option only applies to backup, not init)
  # Using connection multiplexing and aggressive keepalives to prevent timeouts
  programs.ssh.extraConfig = ''
    Host de4729.rsync.net
      IdentityFile /var/run/agenix/syncoid-ssh-key
      ServerAliveInterval 15
      ServerAliveCountMax 4
      # Connection multiplexing - reuse connections
      ControlMaster auto
      ControlPath /tmp/ssh-%r@%h:%p
      ControlPersist 600
      # Faster connection setup
      Compression yes
      TCPKeepAlive yes
  '';

  # Ensure the SSH control socket directory exists and is cleaned up
  systemd.tmpfiles.rules = [
    "d /tmp 1777 root root - -"
  ];

  services.clubcotton.restic = {
    # Set to true after creating secrets/restic-password.age
    enable = true;

    # Directories to backup (same as borgmatic)
    sourceDirectories = [
      "/var/lib"
      "/backups/postgresql"
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
      # Map datasets to their mount points for path translation
      datasetMountPoints = {
        "rpool/local/lib" = "/var/lib";
        "backuppool/local/postgresql" = "/backups/postgresql";
        "mediapool/local/documents" = "/media/documents";
        "mediapool/local/tomcotton/data" = "/media/tomcotton/data";
        "mediapool/local/tomcotton/audio-library" = "/media/tomcotton/audio-library";
      };
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

    # SSH config is set via programs.ssh.extraConfig above for rsync.net
    # No need for sshCommand - SSH config handles identity file and keepalive

    repositories = {
      # rsync.net via SFTP (existing account)
      rsyncnet = {
        repository = "sftp:de4729@de4729.rsync.net:restic-nas-01";
        passwordFile = config.age.secrets.restic-password.path;
        timerConfig = {
          OnCalendar = "daily";
          Persistent = "true";
          RandomizedDelaySec = "1h";
        };
        retention = {
          keepDaily = 7;
          keepWeekly = 4;
          keepMonthly = 6;
          keepYearly = 1;
        };
        extraBackupArgs = [
          "--exclude-caches"
          "--verbose"
          # Limit parallelism to reduce connection strain
          "--pack-size=32"
        ];
        # Limit SFTP connections to prevent overwhelming rsync.net
        extraOptions = [
          "sftp.connections=2"
        ];
      };

      # Backblaze B2 (secondary/redundant)
      # Uncomment after creating restic-password.age and restic-b2-env.age secrets
      b2 = {
        repository = "b2:nas-01-restic-backup";
        passwordFile = config.age.secrets.restic-password.path;
        environmentFile = config.age.secrets.restic-b2-env.path;
        timerConfig = {
          OnCalendar = "daily";
          Persistent = "true";
          RandomizedDelaySec = "2h";
        };
        retention = {
          keepDaily = 7;
          keepWeekly = 4;
          keepMonthly = 12;
          keepYearly = 2;
        };
        extraBackupArgs = [
          "--exclude-caches"
          "--verbose"
        ];
      };
    };

    # Enable Prometheus metrics
    prometheusExporter = {
      enable = true;
      port = 9997;
      refreshInterval = 300;
    };
  };
}
