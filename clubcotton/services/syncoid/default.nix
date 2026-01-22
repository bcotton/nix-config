{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  service = "syncoid";
  cfg = config.services.clubcotton.${service};
in {
  options.services.clubcotton.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      localTargetAllow = [
        "change-key"
        "compression"
        "create"
        "mount"
        "mountpoint"
        "receive"
        "rollback"
        "destroy"
        "snapshot"
      ];
      commands = {
        var_lib = {
          source = "rpool/local/lib";
          target = "backuppool/local/nas-01/var-lib";
        };
        database = {
          source = "ssdpool/local/database";
          target = "backuppool/local/nas-01/database";
        };
        photos = {
          source = "mediapool/local/photos";
          target = "backuppool/local/nas-01/photos";
        };
        documents = {
          source = "mediapool/local/documents";
          target = "backuppool/local/nas-01/documents";
        };
        tomcotton_data = {
          source = "mediapool/local/tomcotton/data";
          target = "backuppool/local/nas-01/tomcotton-data";
        };
        tomcotton_audio_library = {
          source = "mediapool/local/tomcotton/audio-library";
          target = "backuppool/local/nas-01/tomcotton-audio-library";
        };
      };
    };
  };
}
