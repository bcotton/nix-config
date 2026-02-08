{
  pkgs,
  lib,
  ...
}: {
  services.prometheus = {
    exporters = {
      node = {
        enable = true;
        enabledCollectors = ["systemd"];
        port = 9100;
      };
    };
  };

  # Open firewall for Prometheus metrics scraping
  networking.firewall.allowedTCPPorts = [9100];
}
