{
  lib,
  config,
  ...
}:
with lib; let
in {
  services.prometheus.alertmanager = {
    enable = true;
    listenAddress = "";
    logLevel = "debug";
    # webExternalUrl = "https://alertmanager.routing.rocks";
    configuration = {
      route = {
        group_by = ["..."];
        group_wait = "30s";
        receiver = "pushover";
        routes = [
          # Dead Man's Switch route - send Watchdog alerts to healthchecks.io
          {
            match = {
              alertname = "Watchdog";
            };
            receiver = "deadman";
            group_wait = "0s";
            group_interval = "1m";
            repeat_interval = "1h";
          }
        ];
      };
      receivers = [
        {
          name = "pushover";
          pushover_configs = [
            {
              token_file = config.age.secrets.pushover-token.path;
              user_key_file = config.age.secrets.pushover-key.path;
              # severity = "{{ .GroupLabels.severity }}";
            }
          ];
        }
        {
          name = "deadman";
          webhook_configs = [
            {
              url = "https://hc-ping.com/9961cb1a-4367-45b8-870b-2621a0996c28";
              send_resolved = false;
            }
          ];
        }
      ];
    };
  };
}
