{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  service = "forgejo-log-scraper";
  cfg = config.services.clubcotton.${service};

  scraperScript = pkgs.writeShellApplication {
    name = "forgejo-log-scraper";
    runtimeInputs = with pkgs; [curl jq coreutils zstd inotify-tools findutils gnugrep gnused sqlite gawk];
    text = builtins.readFile ./scraper.sh;
  };
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "Forgejo Actions log scraper for Loki";

    logBaseDir = mkOption {
      type = types.str;
      default = "/var/lib/forgejo/data/actions_log";
      description = "Base directory where Forgejo stores actions log files.";
    };

    lokiEndpoint = mkOption {
      type = types.str;
      default = "http://localhost:3100/loki/api/v1/push";
      description = "Loki push endpoint URL.";
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/forgejo-log-scraper";
      description = "Directory for tracking which logs have been processed.";
    };

    maxParallel = mkOption {
      type = types.int;
      default = 4;
      description = "Number of parallel workers for backfill processing.";
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0750 forgejo forgejo - -"
      "f '${cfg.stateDir}/processed.db' 0640 forgejo forgejo - -"
    ];

    systemd.services.forgejo-log-scraper = {
      description = "Watch Forgejo Actions logs and push to Loki";
      after = ["network-online.target" "forgejo.service"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      environment = {
        LOG_BASE_DIR = cfg.logBaseDir;
        LOKI_ENDPOINT = cfg.lokiEndpoint;
        STATE_DIR = cfg.stateDir;
        MAX_PARALLEL = toString cfg.maxParallel;
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = "${scraperScript}/bin/forgejo-log-scraper";
        User = "forgejo";
        Group = "forgejo";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        ProtectSystem = "strict";
        ReadWritePaths = [cfg.stateDir];
        ReadOnlyPaths = [cfg.logBaseDir];
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectHome = true;
      };
    };
  };
}
