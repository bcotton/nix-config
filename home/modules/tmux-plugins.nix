{
  pkgs,
  lib,
  config,
  ...
}: let
  tmux-window-name =
    pkgs.tmuxPlugins.mkTmuxPlugin
    {
      pluginName = "tmux-window-name";
      version = "head";
      src = pkgs.fetchFromGitHub {
        owner = "ofirgall";
        repo = "tmux-window-name";
        rev = "dc97a79ac35a9db67af558bb66b3a7ad41c924e7";
        sha256 = "sha256-o7ZzlXwzvbrZf/Uv0jHM+FiHjmBO0mI63pjeJwVJEhE=";
      };
    };

  tmux-fzf-head =
    pkgs.tmuxPlugins.mkTmuxPlugin
    {
      pluginName = "tmux-fzf";
      version = "head";
      rtpFilePath = "main.tmux";
      src = pkgs.fetchFromGitHub {
        owner = "sainnhe";
        repo = "tmux-fzf";
        rev = "6b31cbe454649736dcd6dc106bb973349560a949";
        sha256 = "sha256-RXoJ5jR3PLiu+iymsAI42PrdvZ8k83lDJGA7MQMpvPY=";
      };
    };

  tmux-nested =
    pkgs.tmuxPlugins.mkTmuxPlugin
    {
      pluginName = "tmux-nested";
      version = "target-style-config";
      src = pkgs.fetchFromGitHub {
        owner = "bcotton";
        repo = "tmux-nested";
        rev = "2878b1d05569a8e41c506e74756ddfac7b0ffebe";
        sha256 = "sha256-w0bKtbxrRZFxs2hekljI27IFzM1pe1HvAg31Z9ccs0U=";
      };
    };

  tmux-fuzzback =
    pkgs.tmuxPlugins.mkTmuxPlugin
    {
      pluginName = "tmux-fuzzback";
      version = "target-style-head";
      src = pkgs.fetchFromGitHub {
        owner = "roosta";
        repo = "tmux-fuzzback";
        rev = "48fa13a2422bab9832543df1c6b4e9c6393e647c";
        sha256 = "sha256-T3rHudl9o4AP13Q4poccfXiDg41LRWThFW0r5IZxGjw=";
      };
    };

  cfg = config.programs.tmux-plugins;
in {
  options.programs.tmux-plugins = {
    enable = lib.mkEnableOption "tmux plugins";
  };

  config = lib.mkIf cfg.enable {
    _module.args = {
      inherit tmux-window-name tmux-fzf-head tmux-nested tmux-fuzzback;
    };

    programs.tmux = {
      plugins = with pkgs.tmuxPlugins; [
        gruvbox
        tmux-colors-solarized
        fzf-tmux-url
        tmux-fzf-head
        tmux-thumbs
        {
          plugin = tmux-window-name;
        }
      ];
      extraConfig = lib.mkAfter ''
        bind-key "C-f" run-shell -b "${tmux-fzf-head}/share/tmux-plugins/tmux-fzf/scripts/session.sh switch"
        run-shell ${tmux-nested}/share/tmux-plugins/tmux-nested/nested.tmux
        run-shell ${tmux-fuzzback}/share/tmux-plugins/tmux-fuzzback/fuzzback.tmux
      '';
    };

    programs.zsh.initContent = ''
      tmux-window-name() {
        (${builtins.toString tmux-window-name}/share/tmux-plugins/tmux-window-name/scripts/rename_session_windows.py &)
      }
      if [[ -n "$TMUX" ]]; then
        add-zsh-hook chpwd tmux-window-name
      fi
    '';
  };
}
