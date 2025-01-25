{
  config,
  pkgs,
  self,
  ...
}: let
  # https://blog.korfuri.fr/posts/2022/11/autogenerated-prometheus-configs-for-multiple-nixos-hosts/
  lib = pkgs.lib;
  # List of exporters to monitor
  monitoredExporters = [
    "node"
    "zfs"
  ];

  # Find all enabled exporters for a host
  enabledExportersF = hostName: host: let
    exporters = host.config.services.prometheus.exporters;
    mkExporter = name:
      if
        builtins.hasAttr name exporters
        && builtins.isAttrs exporters.${name}
        && exporters.${name}.enable or false
      then {${name} = exporters.${name};}
      else {};
  in
    lib.foldl' (acc: name: acc // (mkExporter name)) {} monitoredExporters;

  # Build the scrape config for each enabled exporter
  mkScrapeConfigExporterF = hostname: ename: ecfg: {
    job_name = "${hostname}-${ename}";
    scrape_interval = "30s";
    static_configs = [{targets = ["${hostname}:${toString ecfg.port}"];}];
    relabel_configs = [
      {
        target_label = "instance";
        replacement = "${hostname}";
      }
      {
        target_label = "job";
        replacement = "${ename}";
      }
    ];
  };

  # From all the known hosts, fetch their enabled exporters
  enabledExporters = builtins.mapAttrs enabledExportersF self.nixosConfigurations;

  # Build the scrape config for each host
  mkScrapeConfigHost = name: exporters:
    builtins.mapAttrs (mkScrapeConfigExporterF name) exporters;
  scrapeConfigsByHost = builtins.mapAttrs mkScrapeConfigHost enabledExporters;

  # Check which hosts have tailscale enabled
  enabledTailscaleF = hostName: host:
    if host.config.services.clubcotton.services.tailscale.enable or false
    then true
    else false;

  # Generate scrape configs for tailscale metrics
  mkTailscaleScrapeConfigF = hostname: enabled:
    if enabled
    then [
      {
        job_name = "${hostname}-tailscale";
        scrape_interval = "30s";
        static_configs = [{targets = ["${hostname}:5252"];}];
        relabel_configs = [
          {
            target_label = "instance";
            replacement = "${hostname}";
          }
          {
            target_label = "job";
            replacement = "tailscale";
          }
        ];
      }
    ]
    else [];

  # Get tailscale status for all hosts
  enabledTailscale = builtins.mapAttrs enabledTailscaleF self.nixosConfigurations;

  # Generate tailscale scrape configs
  tailscaleScrapeConfigs = lib.flatten (builtins.attrValues (builtins.mapAttrs mkTailscaleScrapeConfigF enabledTailscale));

  # Flatten the scrapeConfigsByHost into a list and add tailscale configs
  autogenScrapeConfigs = lib.flatten (map builtins.attrValues (builtins.attrValues scrapeConfigsByHost)) ++ tailscaleScrapeConfigs;
in {
  imports = [
    ./alert-manager.nix
  ];

  services.prometheus = {
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
    remoteWrite = [
      {
        name = "alloy";
        url = "http://localhost:9999/api/v1/metrics/write";
      }
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
          static_configs = [
            {
              targets = [
                "http://books"
                "http://photos"
                "https://llm.bobtail-clownfish.ts.net"
                "https://jellyfin.bobtail-clownfish.ts.net"
                "https://radarr.bobtail-clownfish.ts.net"
                "https://sabnzbd.bobtail-clownfish.ts.net"
              ];
            }
          ];
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
      ++ autogenScrapeConfigs;
  };
}
