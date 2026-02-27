# Monitors Loki for missing host log data and exposes results as
# Prometheus metrics via node-exporter's textfile collector.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.loki-host-monitor;

  textfileDir = "/var/lib/prometheus-node-exporter/textfile";

  monitorScript = pkgs.writeShellScript "loki-host-monitor" ''
    set -euo pipefail

    LOKI_URL="${cfg.lokiUrl}"
    PROM_FILE="${textfileDir}/loki_host_logs.prom"
    TMP_FILE="''${PROM_FILE}.tmp"

    # Write header
    cat > "$TMP_FILE" <<'HEADER'
    # HELP loki_host_log_lines_1h Number of log lines received from host in the last hour
    # TYPE loki_host_log_lines_1h gauge
    HEADER

    for host in ${concatStringsSep " " cfg.expectedHosts}; do
      count=$(${pkgs.curl}/bin/curl -sG "$LOKI_URL/loki/api/v1/query" \
        --data-urlencode "query=count_over_time({job=\"systemd-journal\", hostname=\"$host\"}[1h])" \
        --data-urlencode "time=$(${pkgs.coreutils}/bin/date +%s)" \
        --max-time 10 2>/dev/null \
        | ${pkgs.jq}/bin/jq '[.data.result[].value[1] | tonumber] | add // 0' 2>/dev/null \
        || echo 0)

      echo "loki_host_log_lines_1h{hostname=\"$host\"} $count" >> "$TMP_FILE"
    done

    # Atomic rename so Prometheus never reads a partial file
    mv "$TMP_FILE" "$PROM_FILE"
  '';
in {
  options.services.loki-host-monitor = {
    enable = mkEnableOption "Loki host log monitor (textfile collector)";

    lokiUrl = mkOption {
      type = types.str;
      default = "http://localhost:3100";
      description = "Loki HTTP API base URL.";
    };

    expectedHosts = mkOption {
      type = types.listOf types.str;
      description = "Hostnames expected to send logs to Loki.";
    };

    interval = mkOption {
      type = types.str;
      default = "*:0/5";
      description = "systemd calendar interval for checks (default: every 5 minutes).";
    };
  };

  config = mkIf cfg.enable {
    # Ensure the textfile collector directory exists
    systemd.tmpfiles.rules = [
      "d ${textfileDir} 0755 root root - -"
    ];

    # Enable textfile collector in node-exporter
    services.prometheus.exporters.node.extraFlags = [
      "--collector.textfile.directory=${textfileDir}"
    ];

    systemd.services.loki-host-monitor = {
      description = "Query Loki for per-host log counts";
      after = ["network.target"];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = monitorScript;
      };
    };

    systemd.timers.loki-host-monitor = {
      description = "Run Loki host monitor periodically";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.interval;
        RandomizedDelaySec = "30s";
        Persistent = true;
      };
    };
  };
}
