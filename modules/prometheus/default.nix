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
      ]
      ++ scrapeConfigs.autogenScrapeConfigs;
  };
}
