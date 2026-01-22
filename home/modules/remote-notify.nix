{
  config,
  lib,
  pkgs,
  localPackages,
  ...
}:
with lib; let
  cfg = config.programs.remote-notify;
in {
  options.programs.remote-notify = {
    enable = mkEnableOption "remote-notify - send notifications to remote Mac via SSH tunnel";

    port = mkOption {
      type = types.port;
      default = 7892;
      description = "Port where notification-receiver listens (via SSH RemoteForward)";
    };
  };

  config = mkIf (cfg.enable && pkgs.stdenv.isLinux) {
    home.packages = [localPackages.remote-notify];

    # Set environment variables
    home.sessionVariables = {
      REMOTE_NOTIFY_PORT = toString cfg.port;
    };
  };
}
