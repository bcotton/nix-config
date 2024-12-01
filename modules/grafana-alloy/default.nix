{
  config,
  pkgs,
  unstablePkgs,
  inputs,
  ...
}: {
  # Can't seem to get LoadCredential to work, it would appear that the
  # permissions on the file are not correct.
  systemd.services.alloy.serviceConfig = {
    StateDirectory = "alloy";
    # LoadCredential = [
    #   "token:${config.age.secrets.grafana-cloud.path}"
    # ];
    # Environment = "TOKENPATH=%d/token";
    EnvironmentFile = config.age.secrets.grafana-cloud.path;
  };

  services.alloy = {
    enable = true;
    configPath = let
      configAlloy = pkgs.writeText "config.alloy" ''

        prometheus.exporter.self "alloy" {
        }

        prometheus.scrape "metamonitoring" {
           targets    = prometheus.exporter.self.alloy.targets
           forward_to = [grafana_cloud.stack.receivers.metrics]
        }

        prometheus.receive_http "api" {
          http {
            listen_address = "0.0.0.0"
            listen_port = 9999
          }
          forward_to = [grafana_cloud.stack.receivers.metrics]
        }


          import.git "grafana_cloud" {
            repository = "https://github.com/grafana/alloy-modules.git"
            revision = "main"
            path = "modules/cloud/grafana/cloud/module.alloy"
            pull_frequency = "15m"
          }

          // get the receivers
          grafana_cloud.stack "receivers" {
            stack_name = "clubcotton"
            token = sys.env("TOKEN")
          }

          // scrape metrics and write to grafana cloud
          prometheus.scrape "default" {
            targets = [
              {
              "__address__" = "[::1]:${builtins.toString config.services.prometheus.exporters.node.port}",
              "instance" = "${builtins.toString config.networking.hostName}",
              },
            ]
            forward_to = [
              grafana_cloud.stack.receivers.metrics,
            ]
          }
      '';
    in
      pkgs.runCommand "grafana-alloy.d" {} ''
        mkdir $out
        cp "${configAlloy}" "$out/config.alloy"
      '';
  };

  #   passthru = {
  #     fqdn = "grafana-alloy.${config.networking.domain}";
  #   };
}
