{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  service = "alloy-logs";
  cfg = config.services.clubcotton.${service};

  extraLabelsStr =
    concatStringsSep "\n"
    (mapAttrsToList (k: v: ''${k} = "${v}",'') cfg.extraLabels);

  alloyConfig = pkgs.writeText "config.alloy" ''
    loki.source.journal "systemd" {
      forward_to    = [loki.write.default.receiver]
      relabel_rules = loki.relabel.journal.rules
      path          = "/var/log/journal"
      labels        = {
        job      = "systemd-journal",
        hostname = "${config.networking.hostName}",
    ${extraLabelsStr}
      }
    }

    loki.relabel "journal" {
      forward_to = [loki.write.default.receiver]

      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }
      rule {
        source_labels = ["__journal_syslog_identifier"]
        target_label  = "syslog_identifier"
      }
      rule {
        source_labels = ["__journal__transport"]
        target_label  = "transport"
      }
      rule {
        source_labels = ["__journal_priority_keyword"]
        target_label  = "priority"
      }
    }

    loki.write "default" {
      endpoint {
        url = "${cfg.lokiEndpoint}"
      }
    }
  '';
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "Grafana Alloy log collection agent";

    lokiEndpoint = mkOption {
      type = types.str;
      default = "http://nas-01.lan:3100/loki/api/v1/push";
      description = "Loki push endpoint URL.";
    };

    httpListenPort = mkOption {
      type = types.port;
      default = 12346;
      description = "Port for Alloy's internal UI/metrics (bound to localhost).";
    };

    extraLabels = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Additional static labels to attach to all log entries.";
    };
  };

  config = mkIf cfg.enable {
    services.alloy = {
      enable = true;
      extraFlags = [
        "--server.http.listen-addr=127.0.0.1:${toString cfg.httpListenPort}"
        "--disable-reporting"
      ];
      configPath = pkgs.runCommand "alloy-logs.d" {} ''
        mkdir $out
        cp "${alloyConfig}" "$out/config.alloy"
      '';
    };
  };
}
