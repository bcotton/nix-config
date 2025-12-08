{
  lib,
  config,
  ...
}: {
  imports = [
    ./services
  ];

  config = {
    users = {
      groups.share = {
        gid = 1100;
      };
      users.share = {
        uid = 1100;
        isSystemUser = true;
        group = "share";
      };
    };
  };

  options.clubcotton = {
    user = lib.mkOption {
      default = "share";
      type = lib.types.str;
      description = ''
        User to run the homelab services as
      '';
      #apply = old: builtins.toString config.users.users."${old}".uid;
    };
    group = lib.mkOption {
      default = "share";
      type = lib.types.str;
      description = ''
        Group to run the homelab services as
      '';
      #apply = old: builtins.toString config.users.groups."${old}".gid;
    };
    tailscaleAuthKeyPath = lib.mkOption {
      type = lib.types.str;
      default = config.age.secrets.tailscale-keys.path;
      description = "The path to the age-encrypted TS auth key";
    };
  };

  # Global configuration for all tsnsrv services to force login
  config.systemd.services = lib.mkIf (config.services.tsnsrv.enable or false) (
    lib.mapAttrs' (name: _: lib.nameValuePair "tsnsrv-${name}" {
      environment.TSNET_FORCE_LOGIN = "1";
    }) config.services.tsnsrv.services
  );
}
