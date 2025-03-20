{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  service = "bonob";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "Bonob Sonos server";

    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Port to run Bonob on";
    };

    url = mkOption {
      type = types.str;
      default = "http://localhost:3000";
      description = "URL where this Bonob server can be reached";
    };

    subsonicUrl = mkOption {
      type = types.str;
      description = "URL of the Subsonic server to connect to";
    };

    sonosSeedHost = mkOption {
      type = types.str;
      description = "IP address of a Sonos device to use as seed for discovery";
    };

    autoRegister = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically register with discovered Sonos devices";
    };

    deviceDiscovery = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable Sonos device discovery";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.${service} = {
      image = "simojenki/bonob:latest";
      autoStart = true;
      environment = {
        BNB_PORT = toString cfg.port;
        BNB_URL = cfg.url;
        BNB_SUBSONIC_URL = cfg.subsonicUrl;
        BNB_SONOS_SEED_HOST = cfg.sonosSeedHost;
        BNB_SONOS_AUTO_REGISTER = boolToString cfg.autoRegister;
        BNB_SONOS_DEVICE_DISCOVERY = boolToString cfg.deviceDiscovery;
        # Force flac re-encode for the sonos flac support
        BNB_SUBSONIC_CUSTOM_CLIENTS = "audio/flac";
      };
      ports = ["${toString cfg.port}:${toString cfg.port}"];
    };
  };
}
