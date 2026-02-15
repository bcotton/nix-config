{
  config,
  pkgs,
  ...
}: {
  services.grafana = {
    enable = true;
    settings.server.http_port = 3000;
    settings.server.http_addr = "0.0.0.0";

    declarativePlugins = with pkgs.grafanaPlugins; [
      grafana-piechart-panel
      grafana-clock-panel
      (grafanaPlugin {
        pname = "yesoreyeram-infinity-datasource";
        version = "0.8.8";
        zipHash = "sha256-SiG3fimQjJ+qLq59So6zaGanpf8gg8sjsFSMfABf62o=";
      })
      (grafanaPlugin {
        pname = "natel-discrete-panel";
        version = "0.0.9";
        zipHash = "sha256-GiZCE9/ZXuRCukVIfVWvrv0GUEioiseAv7sOLwk128Q=";
      })
      (grafanaPlugin {
        pname = "grafana-lokiexplore-app";
        version = "1.0.35";
        zipHash = "sha256-9iK0h1LRl3PNvu70Aa0cQb8nhqezOKu3PAE2GsRR11s=";
      })
      (grafanaPlugin {
        pname = "grafana-metricsdrilldown-app";
        version = "1.0.30";
        zipHash = "sha256-Il7XV9+ooheasqJIqRmcXWB5mLwEePk4nLP0c4H0Ims=";
      })
    ];

    provision = {
      enable = true;

      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://localhost:${toString config.services.prometheus.port}";
          isDefault = true;
        }
        {
          name = "Mimir";
          type = "prometheus";
          access = "proxy";
          uid = "PAE45454D0EDB9216";
          url = "http://nas-01.lan:9009/prometheus";
          isDefault = false;
        }
        {
          name = "Loki";
          type = "loki";
          access = "proxy";
          uid = "loki-datasource";
          url = "http://nas-01.lan:3100";
          isDefault = false;
        }
      ];

      dashboards.settings.providers = [
        {
          name = "Borgmatic Backups";
          type = "file";
          options.path = ./dashboards;
          disableDeletion = true;
          updateIntervalSeconds = 86400;
        }
      ];
    };
  };

  services.tsnsrv = {
    enable = true;
    defaults.authKeyPath = config.clubcotton.tailscaleAuthKeyPath;
    services."grafana" = {
      ephemeral = true;
      toURL = "http://127.0.0.1:3000/";
    };
  };
}
