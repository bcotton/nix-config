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

  # Generate file match + source blocks for each file target
  mkFileTargetLabels = target: let
    allLabels =
      {
        job = target.job;
        hostname = config.networking.hostName;
      }
      // target.extraLabels;
  in
    concatStringsSep "\n" (mapAttrsToList (k: v: ''${k} = "${v}",'') allLabels);

  mkFileSourceBlock = target: ''
    local.file_match "${target.job}" {
      path_targets = [{
        __path__ = "${target.path}",
    ${mkFileTargetLabels target}
      }]
    }

    loki.source.file "${target.job}" {
      targets    = local.file_match.${target.job}.targets
      forward_to = [loki.write.default.receiver]
    }
  '';

  fileSourceBlocks = concatStringsSep "\n" (map mkFileSourceBlock cfg.fileTargets);

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
        source_labels = ["__journal__systemd_user_unit"]
        target_label  = "user_unit"
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

    ${fileSourceBlocks}

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

    fileTargets = mkOption {
      type = types.listOf (types.submodule {
        options = {
          job = mkOption {
            type = types.str;
            description = "Job name used as Alloy component identifier and Loki label.";
          };
          path = mkOption {
            type = types.str;
            description = "Glob pattern for log files to tail (e.g. /var/log/app/*.log).";
          };
          extraLabels = mkOption {
            type = types.attrsOf types.str;
            default = {};
            description = "Additional labels to attach to entries from these files.";
          };
        };
      });
      default = [];
      description = "File paths to tail and forward to Loki.";
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

    # DynamicUser=true (set by the upstream alloy module) implies PrivateTmp,
    # so Alloy can't see files under /tmp. Bind-mount each fileTarget's parent
    # directory read-only into the service namespace.
    systemd.services.alloy.serviceConfig.BindReadOnlyPaths = let
      # Extract parent directory from a glob path (strip the filename/glob portion)
      parentDir = path: dirOf path;
      dirs = unique (map (t: parentDir t.path) cfg.fileTargets);
    in
      mkIf (cfg.fileTargets != []) dirs;
  };
}
