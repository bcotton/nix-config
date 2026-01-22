{
  config,
  lib,
  pkgs,
  localPackages,
  ...
}:
with lib; let
  cfg = config.programs.clipboard-receiver;
in {
  options.programs.clipboard-receiver = {
    enable = mkEnableOption "clipboard-receiver - TCP listener that copies text to local clipboard";

    port = mkOption {
      type = types.port;
      default = 7891;
      description = "Port to listen on for incoming clipboard requests";
    };
  };

  # Configuration is minimal for Home Manager - the launchd agent is in darwin-common.nix
  # This module just provides the enable option that darwin-common.nix checks
  config = mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
    # Ensure the package is available
    home.packages = [localPackages.clipboard-receiver];
  };
}
