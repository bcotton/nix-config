{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.nvm-lazy;
in {
  options.programs.nvm-lazy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable lazy-loading NVM";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh.envExtra = lib.mkAfter ''
      export NVM_DIR="$HOME/.nvm"

      # Lazy loaders that remove themselves on first use
      nvm() {
        unfunction nvm node npm
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        nvm "$@"
      }

      node() {
        unfunction node nvm npm
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        node "$@"
      }

      npm() {
        unfunction npm nvm node
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        npm "$@"
      }
    '';
  };
}
