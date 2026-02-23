{
  config,
  lib,
  pkgs,
  ...
}: {
  # Incus metrics collector for Prometheus via node-exporter textfile collector
  # Follows the same pattern as modules/zfs/monitoring.nix

  systemd.services.incus-metrics-collector = lib.mkIf config.virtualisation.incus.enable {
    description = "Collect Incus metrics for Prometheus";
    after = ["incus.service"];
    wants = ["incus.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "incus-metrics-collector" ''
        TEXTFILE_DIR="/var/lib/prometheus-node-exporter-text-files"
        mkdir -p "$TEXTFILE_DIR"

        # Fetch metrics from Incus local unix socket
        # Strip OpenMetrics-only features not supported by node-exporter textfile collector:
        #   - "# EOF" terminator line
        #   - "_created" suffix metrics (counter creation timestamps)
        METRICS=$(${pkgs.incus}/bin/incus query /1.0/metrics 2>/dev/null || true)

        if [ -n "$METRICS" ]; then
          echo "$METRICS" \
            | ${pkgs.gnugrep}/bin/grep -v '^# EOF$' \
            | ${pkgs.gnugrep}/bin/grep -v '_created{' \
            | ${pkgs.gnugrep}/bin/grep -v '_created ' \
            > "$TEXTFILE_DIR/incus.prom.tmp"
          chmod 644 "$TEXTFILE_DIR/incus.prom.tmp"
          mv "$TEXTFILE_DIR/incus.prom.tmp" "$TEXTFILE_DIR/incus.prom"
        else
          # Incus daemon not ready or no metrics — write empty file to avoid stale data
          : > "$TEXTFILE_DIR/incus.prom.tmp"
          chmod 644 "$TEXTFILE_DIR/incus.prom.tmp"
          mv "$TEXTFILE_DIR/incus.prom.tmp" "$TEXTFILE_DIR/incus.prom"
        fi
      '';
      User = "root";
      Group = "root";
    };
  };

  systemd.timers.incus-metrics-collector = lib.mkIf config.virtualisation.incus.enable {
    description = "Collect Incus metrics every 15 seconds";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*:*:0/15";
      Persistent = true;
    };
  };

  # Ensure textfile directory exists
  systemd.tmpfiles.rules = lib.mkIf config.virtualisation.incus.enable [
    "d /var/lib/prometheus-node-exporter-text-files 0755 root root - -"
  ];

  # Note: textfile collector on node-exporter is configured by modules/zfs/monitoring.nix
  # which uses the same directory. No need to duplicate here.
}
