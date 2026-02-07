{
  config,
  pkgs,
  self,
  lib,
  ...
}: let
  # Import the prometheus configuration library
  promLib = import ./lib.nix {lib = pkgs.lib;};
  # Get all scrape configurations
  scrapeConfigs = promLib.mkScrapeConfigs self (config.services.prometheus.tsnsrvExcludeList or []);
in {
  imports = [
    ./alert-manager.nix
    ./nix-build-cache-check.nix
  ];

  options.services.prometheus = {
    tsnsrvExcludeList = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["service1" "service2"];
      description = lib.mdDoc ''
        List of tsnsrv service names to exclude from blackbox monitoring.
        These services will not be included in the blackbox exporter targets.
      '';
    };
  };

  config.services.prometheus = {
    enable = true;
    port = 9001;
    extraFlags = [
      "--log.level=debug"
    ];
    checkConfig = "syntax-only";
    rules = [
      (builtins.readFile ./prometheus.rules.yaml)
    ];

    # Send to the local Alloy instance for forwarding to Grafana Cloud
    # remoteWrite = [
    #   {
    #     name = "alloy";
    #     url = "http://localhost:9999/api/v1/metrics/write";
    #   }
    # ];

    exporters = {
      blackbox = {
        enable = true;
        configFile = "${./blackbox.yml}";
      };
      smokeping = {
        enable = true;
        hosts = [
          "admin"
          "shelly-smokedetector"
          "shelly-codetecter"
          "192.168.20.105"
          "75.166.123.123"
          "1.1.1.1"
          "8.8.8.8"
        ];
      };
      # unpoller = {
      #   enable = true;
      # };
    };

    alertmanagers = [
      {
        scheme = "http";
        static_configs = [
          {
            targets = [
              "127.0.0.1:${toString config.services.prometheus.alertmanager.port}"
            ];
          }
        ];
      }
    ];

    scrapeConfigs =
      [
        {
          job_name = "borgmatic";
          scrape_interval = "5m"; # Check every 5 minutes - backups run daily
          scrape_timeout = "30s"; # Reasonable timeout for borgmatic to gather stats
          static_configs = [
            {
              targets = ["nas-01:9996"];
            }
          ];
        }
        {
          job_name = "unpoller";
          static_configs = [
            {
              targets = ["localhost:${toString config.services.prometheus.exporters.unpoller.port}"];
            }
          ];
        }
        {
          job_name = "smokeping";
          static_configs = [
            {
              targets = ["localhost:${toString config.services.prometheus.exporters.smokeping.port}"];
            }
          ];
        }
        {
          job_name = "condo-ha";
          honor_timestamps = true;
          scrape_interval = "30s";
          scrape_timeout = "10s";
          metrics_path = "/api/prometheus";
          scheme = "http";
          bearer_token_file = config.age.secrets.condo-ha-token.path;
          static_configs = [
            {
              targets = ["condo-ha:8123"];
            }
          ];
        }
        {
          job_name = "homeassistant";
          honor_timestamps = true;
          scrape_interval = "30s";
          scrape_timeout = "10s";
          metrics_path = "/api/prometheus";
          scheme = "http";
          bearer_token_file = config.age.secrets.homeassistant-token.path;
          static_configs = [
            {
              targets = ["homeassistant:8123"];
            }
          ];
        }
        {
          job_name = "blackbox_http";
          metrics_path = "/probe";
          params = {
            module = ["http_2xx"];
          };
          static_configs = scrapeConfigs.tsnsrvBlackboxConfigs;
          relabel_configs = [
            {
              source_labels = ["__address__"];
              target_label = "__param_target";
            }
            {
              source_labels = ["__param_target"];
              target_label = "instance";
            }
            {
              target_label = "__address__";
              replacement = "127.0.0.1:9115";
            }
          ];
        }
        {
          job_name = "dns_resolution";
          metrics_path = "/probe";
          params = {
            module = ["dns_nas01"];
          };
          static_configs = [
            {
              targets = ["192.168.5.220:53"]; # dns-01.lan
              labels = {
                check = "nas-01.lan";
                expected_ip = "192.168.5.42";
              };
            }
          ];
          relabel_configs = [
            {
              source_labels = ["__address__"];
              target_label = "__param_target";
            }
            {
              source_labels = ["__param_target"];
              target_label = "dns_server";
            }
            {
              target_label = "__address__";
              replacement = "127.0.0.1:9115"; # blackbox exporter
            }
          ];
        }
        {
          job_name = "homeassistant_node";
          scrape_interval = "30s";
          static_configs = [
            {
              targets = ["homeassistant:9100"];
            }
          ];
          relabel_configs = [
            {
              target_label = "instance";
              replacement = "homeassistant";
            }
            {
              target_label = "job";
              replacement = "node";
            }
          ];
        }
        {
          job_name = "condo_ha_node";
          scrape_interval = "30s";
          static_configs = [
            {
              targets = ["condo-ha:9100"];
            }
          ];
          relabel_configs = [
            {
              target_label = "instance";
              replacement = "condo-ha";
            }
            {
              target_label = "job";
              replacement = "node";
            }
          ];
        }
      ]
      ++ scrapeConfigs.autogenScrapeConfigs;
  };
}
