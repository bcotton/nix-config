{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.clubcotton.services.tailscale;
in {
  options.services.clubcotton.services.tailscale = {
    enable = mkEnableOption "tailscale service";
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedUDPPorts = [config.services.tailscale.port];
    networking.firewall.trustedInterfaces = ["tailscale0"];

    services.tailscale = {
      enable = true;
      package = pkgs.tailscale;
      authKeyFile = config.age.secrets.tailscale-keys.path;
    };

    # Add oneshot service to enable webclient
    systemd.services.tailscale-webclient = {
      description = "Enable Tailscale webclient";
      after = ["tailscale.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.tailscale}/bin/tailscale set --webclient";
        RemainAfterExit = true;
      };
    };
  };
}
