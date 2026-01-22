{
  config,
  lib,
  pkgs,
  localPackages,
  ...
}:
with lib; let
  cfg = config.programs.browser-opener;
in {
  options.programs.browser-opener = {
    enable = mkEnableOption "browser-opener - TCP listener that opens URLs in local browser";

    port = mkOption {
      type = types.port;
      default = 7890;
      description = "Port to listen on for incoming URL requests";
    };
  };

  # Configuration is minimal for Home Manager - the launchd agent is in darwin-common.nix
  # This module just provides the enable option that darwin-common.nix checks
  config = mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
    # Ensure the package is available
    home.packages = [localPackages.browser-opener];
  };
}
