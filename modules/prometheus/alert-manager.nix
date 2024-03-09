{
  lib,
  config,
  ...
}:
with lib; let
in {
  services.prometheus.alertmanager = {
    enable = true;
    listenAddress = "127.0.0.1";
    # webExternalUrl = "https://alertmanager.routing.rocks";
    configuration = {
      route = {
        group_by = ["..."];
        group_wait = "30s";
        receiver = "pushover";
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
      ];
    };
  };
}
