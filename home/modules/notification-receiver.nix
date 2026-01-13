{
  config,
  lib,
  pkgs,
  localPackages,
  ...
}:
with lib; let
  cfg = config.programs.notification-receiver;
in {
  options.programs.notification-receiver = {
    enable = mkEnableOption "notification-receiver - TCP listener that displays macOS notifications";

    port = mkOption {
      type = types.port;
      default = 7892;
      description = "Port to listen on for incoming notification requests";
    };
  };

  # Configuration is minimal for Home Manager - the launchd agent is in darwin-common.nix
  # This module just provides the enable option that darwin-common.nix checks
  config = mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
    # Ensure the package is available
    home.packages = [localPackages.notification-receiver];
  };
}
