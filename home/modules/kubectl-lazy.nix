{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.kubectl-lazy;
in {
  options.programs.kubectl-lazy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable lazy-loading kubectl completions";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh.initContent = lib.mkAfter ''
      # Lazy-load kubectl completions on first use
      kubectl() {
        # Remove this wrapper function
        unfunction kubectl

        # Load kubectl completions
        source <(command kubectl completion zsh)

        # Re-create alias
        alias k=kubectl

        # Run kubectl with original arguments
        command kubectl "$@"
      }

      # Create initial alias that uses the wrapper
      alias k=kubectl
    '';
  };
}
