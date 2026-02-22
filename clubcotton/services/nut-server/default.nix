{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  service = "nut-server";
  cfg = config.services.clubcotton.${service};
in {
  options.services.clubcotton.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
  };
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [3493];

    power.ups = {
      enable = true;
      mode = lib.mkForce "netserver";
      ups."server-rack-ups" = {
        driver = "usbhid-ups";
        port = "auto";
        directives = [
          "vendorid = 0764" # Result from `lsusb`
          "productid = 0601" # Result from `lsusb`
        ];
      };

      upsd.listen = [
        {
          address = "0.0.0.0";
        }
      ];

      upsmon.monitor = {
        "server-rack-ups" = {
          system = "server-rack-ups@admin.lan:3493";
          powerValue = 1;
          user = "primary-client";
        };
      };

      users = {
        # Upsmon makes the following distinction between users:
        # * primary = "UPS is connected to this machine, shut it down last"
        # * secondary = "UPS" is not connected to this machine, start shutdown here first
        primary-client = {
          passwordFile = config.age.secrets.nut-client-password.path;
          upsmon = "primary";
        };
        secondary-client = {
          passwordFile = config.age.secrets.nut-client-password.path;
          upsmon = "secondary";
        };
      };
    };
  };
}
