{
  config,
  lib,
  pkgs,
  localPackages,
  ...
}:
with lib; let
  cfg = config.programs.remote-copy;
in {
  options.programs.remote-copy = {
    enable = mkEnableOption "remote-copy - copy text to remote clipboard via SSH tunnel";

    port = mkOption {
      type = types.port;
      default = 7891;
      description = "Port where clipboard-receiver listens (via SSH RemoteForward)";
    };

    createPbcopyAlias = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to create a pbcopy alias for remote-copy";
    };
  };

  config = mkIf (cfg.enable && pkgs.stdenv.isLinux) {
    home.packages = [localPackages.remote-copy];

    # Set environment variables
    home.sessionVariables = {
      REMOTE_CLIPBOARD_PORT = toString cfg.port;
    };

    # Create pbcopy alias to use remote clipboard (like macOS)
    programs.zsh.shellAliases = mkIf cfg.createPbcopyAlias {
      pbcopy = "${localPackages.remote-copy}/bin/remote-copy";
    };

    programs.bash.shellAliases = mkIf cfg.createPbcopyAlias {
      pbcopy = "${localPackages.remote-copy}/bin/remote-copy";
    };
  };
}
