{
  config,
  lib,
  pkgs,
  localPackages,
  ...
}:
with lib; let
  cfg = config.programs.arc-tab-archiver;
in {
  options.programs.arc-tab-archiver = {
    enable = mkEnableOption "arc-tab-archiver - Capture auto-archived Arc browser tabs to Obsidian";

    obsidianDir = mkOption {
      type = types.str;
      description = "Directory for output files (e.g., ~/vault/arc-archive)";
      example = "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Bob's Projects/arc-archive";
    };

    interval = mkOption {
      type = types.int;
      default = 1800;
      description = "Run interval in seconds (default: 1800 = 30 minutes)";
    };
  };

  # Configuration is minimal for Home Manager - the launchd agent is in darwin-common.nix
  # This module just provides the enable option that darwin-common.nix checks
  config = mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
    # Ensure the package is available
    home.packages = [localPackages.arc-tab-archiver];
  };
}
