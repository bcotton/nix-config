{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.omz-lazy-plugins;
in {
  options.programs.omz-lazy-plugins = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable lazy-loading of oh-my-zsh plugins";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh.initContent = lib.mkAfter ''
      # Lazy-load oh-my-zsh plugins on first use
      # This creates wrapper functions that load the plugin on first command use

      # Lazy-load brew plugin (provides: cask, brews, etc.)
      brew() {
        unfunction brew cask brews 2>/dev/null
        source $ZSH/plugins/brew/brew.plugin.zsh
        brew "$@"
      }

      # Lazy-load bundler plugin (provides: be, bu, bi, etc.)
      for cmd in bundle be bu bi; do
        eval "$cmd() {
          unfunction bundle be bu bi 2>/dev/null
          source \$ZSH/plugins/bundler/bundler.plugin.zsh
          $cmd \"\$@\"
        }"
      done

      # Lazy-load colorize plugin (provides: ccat, cless)
      for cmd in ccat cless; do
        eval "$cmd() {
          unfunction ccat cless 2>/dev/null
          source \$ZSH/plugins/colorize/colorize.plugin.zsh
          $cmd \"\$@\"
        }"
      done

      # Lazy-load gh plugin (GitHub CLI)
      gh() {
        unfunction gh 2>/dev/null
        source $ZSH/plugins/gh/gh.plugin.zsh
        gh "$@"
      }

      # Lazy-load tmux plugin (provides: ta, tksv, etc.)
      # Note: Only lazy-load if not already in tmux
      if [[ -z "$TMUX" ]]; then
        for cmd in ta tksv tkss mux; do
          eval "$cmd() {
            unfunction ta tksv tkss mux 2>/dev/null
            source \$ZSH/plugins/tmux/tmux.plugin.zsh
            $cmd \"\$@\"
          }"
        done
      fi
    '';
  };
}
