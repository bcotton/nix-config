{
  config,
  lib,
  pkgs,
  localPackages,
  ...
}:
with lib; let
  cfg = config.programs.gwtmux;
in {
  options.programs.gwtmux = {
    enable = lib.mkEnableOption "gwtmux - git worktree and tmux integration";

    package = lib.mkOption {
      type = lib.types.package;
      default = localPackages.gwtmux;
      defaultText = lib.literalExpression "localPackages.gwtmux";
      description = "The gwtmux package to use";
    };

    enableZshIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable zsh integration";
    };

    enableBashIntegration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable bash integration";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [cfg.package];

    programs.zsh.initContent = mkIf cfg.enableZshIntegration ''
      # Load gwtmux function
      source ${cfg.package}/share/gwtmux/gwtmux.sh
    '';

    programs.bash.initExtra = mkIf cfg.enableBashIntegration ''
      # Load gwtmux function
      source ${cfg.package}/share/gwtmux/gwtmux.sh
    '';
  };
}

