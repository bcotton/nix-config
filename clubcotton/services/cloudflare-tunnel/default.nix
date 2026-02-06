{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  service = "cloudflare-tunnel";
  cfg = config.services.clubcotton.${service};
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "Cloudflare Tunnel for secure internet exposure";

    tokenFile = mkOption {
      type = types.path;
      description = ''
        Path to file containing the Cloudflare Tunnel token.
        Get this from: Zero Trust -> Networks -> Tunnels -> Create -> select Cloudflared -> copy token
      '';
      example = "config.age.secrets.cloudflare-tunnel-token.path";
    };
  };

  config = mkIf cfg.enable {
    # Run cloudflared as a systemd service with the tunnel token
    systemd.services.cloudflared-tunnel = {
      description = "Cloudflare Tunnel";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      script = ''
        exec ${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token "$(cat ${cfg.tokenFile})"
      '';

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 5;
        User = "cloudflared";
        Group = "cloudflared";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

    # Create dedicated user for cloudflared
    users.users.cloudflared = {
      isSystemUser = true;
      group = "cloudflared";
      description = "Cloudflare Tunnel daemon user";
    };

    users.groups.cloudflared = {};
  };
}
