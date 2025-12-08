{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enhanced ZFS monitoring configuration
  # This module provides additional monitoring capabilities for ZFS systems
  
  # Systemd metrics are collected via node exporter systemd collector
  # The node exporter is already configured with systemd collector enabled
  # in modules/node-exporter/default.nix, so no additional configuration needed

  # Create a custom ZFS health check script
  systemd.services.zfs-health-check = lib.mkIf (
    config.clubcotton.zfs_single_root.enable
    or false
    || config.clubcotton.zfs_mirrored_root.enable or false
    || config.clubcotton.zfs_raidz1.enable or false
  ) {
    description = "ZFS Health Check for Prometheus";
    wantedBy = [ "multi-user.target" ];
    after = [ "zfs.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "zfs-health-check" ''
        #!/bin/bash
        # Export ZFS health metrics to a file for node_exporter textfile collector
        
        TEXTFILE_DIR="/var/lib/prometheus-node-exporter-text-files"
        mkdir -p "$TEXTFILE_DIR"
        
        # ZFS pool health check
        {
          echo "# HELP zfs_pool_health_detailed ZFS pool health status (0=ONLINE, 1=DEGRADED, 2=FAULTED, 3=OFFLINE, 4=UNAVAIL, 5=REMOVED)"
          echo "# TYPE zfs_pool_health_detailed gauge"
          
          ${pkgs.zfs}/bin/zpool list -H -o name,health | while read pool health; do
            case "$health" in
              "ONLINE") value=0 ;;
              "DEGRADED") value=1 ;;
              "FAULTED") value=2 ;;
              "OFFLINE") value=3 ;;
              "UNAVAIL") value=4 ;;
              "REMOVED") value=5 ;;
              *) value=99 ;;
            esac
            echo "zfs_pool_health_detailed{pool=\"$pool\",health=\"$health\"} $value"
          done
          
          echo "# HELP zfs_scrub_age_seconds Time since last scrub completion"
          echo "# TYPE zfs_scrub_age_seconds gauge"
          
          ${pkgs.zfs}/bin/zpool status | ${pkgs.gawk}/bin/awk '
            /pool:/ { pool = $2 }
            /scrub repaired/ { 
              cmd = "date -d \"" $4 " " $5 " " $6 " " $7 "\" +%s 2>/dev/null || date -d \"" $4 " " $5 " " $7 "\" +%s"
              cmd | getline scrub_time
              close(cmd)
              if (scrub_time) {
                age = systime() - scrub_time
                print "zfs_scrub_age_seconds{pool=\"" pool "\"} " age
              }
            }
          '
        } > "$TEXTFILE_DIR/zfs_health.prom.tmp"
        
        # Set proper permissions for node-exporter to read
        chmod 644 "$TEXTFILE_DIR/zfs_health.prom.tmp"
        mv "$TEXTFILE_DIR/zfs_health.prom.tmp" "$TEXTFILE_DIR/zfs_health.prom"
      '';
      User = "root";
      Group = "root";
    };
  };

  # Run health check every 5 minutes
  systemd.timers.zfs-health-check = lib.mkIf (
    config.clubcotton.zfs_single_root.enable
    or false
    || config.clubcotton.zfs_mirrored_root.enable or false
    || config.clubcotton.zfs_raidz1.enable or false
  ) {
    description = "Run ZFS health check every 5 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/5";  # Every 5 minutes
      Persistent = true;
    };
  };

  # Ensure textfile directory exists and has correct permissions
  # Root writes files, node-exporter reads them
  systemd.tmpfiles.rules = lib.mkIf (
    config.clubcotton.zfs_single_root.enable
    or false
    || config.clubcotton.zfs_mirrored_root.enable or false
    || config.clubcotton.zfs_raidz1.enable or false
  ) [
    "d /var/lib/prometheus-node-exporter-text-files 0755 root node-exporter - -"
  ];

  # Configure node_exporter to collect textfile metrics
  services.prometheus.exporters.node = lib.mkIf (
    config.clubcotton.zfs_single_root.enable
    or false
    || config.clubcotton.zfs_mirrored_root.enable or false
    || config.clubcotton.zfs_raidz1.enable or false
  ) {
    enabledCollectors = [ "textfile" ];
    extraFlags = [ "--collector.textfile.directory=/var/lib/prometheus-node-exporter-text-files" ];
  };

  # Install ZFS disk health check script
  environment.systemPackages = lib.mkIf (
    config.clubcotton.zfs_single_root.enable
    or false
    || config.clubcotton.zfs_mirrored_root.enable or false
    || config.clubcotton.zfs_raidz1.enable or false
  ) [
    (pkgs.writeShellScriptBin "check-zfs-disk-health" (builtins.readFile ./check-disk-health.sh))
  ];
}
