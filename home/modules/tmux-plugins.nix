{
  pkgs,
  lib,
  config,
  localPackages,
  ...
}: let
  # tmux-window-name requires Python with libtmux
  # We wrap the plugin to use the correct Python environment
  tmux-window-name = let
    pythonWithLibtmux = pkgs.python312.withPackages (ps: [ps.libtmux]);
    unwrapped = pkgs.tmuxPlugins.mkTmuxPlugin {
      pluginName = "tmux-window-name";
      version = "head";
      src = pkgs.fetchFromGitHub {
        owner = "ofirgall";
        repo = "tmux-window-name";
        rev = "dc97a79ac35a9db67af558bb66b3a7ad41c924e7";
        sha256 = "sha256-o7ZzlXwzvbrZf/Uv0jHM+FiHjmBO0mI63pjeJwVJEhE=";
      };
    };
    wrapped = pkgs.runCommand "tmux-window-name-wrapped" {} ''
      cp -r ${unwrapped} $out
      chmod -R +w $out

      # Replace Python shebangs with the correct Python path
      for f in $(find $out -name "*.py"); do
        if [[ -f "$f" ]]; then
          sed -i '1s|^#!.*python.*|#!${pythonWithLibtmux}/bin/python|' "$f"
        fi
      done

      # Patch the main tmux script to skip pip check (we know libtmux is available)
      sed -i '/pip_list=/,/exit 0/d' $out/share/tmux-plugins/tmux-window-name/tmux_window_name.tmux
    '';
  in
    wrapped
    // {
      inherit (unwrapped) pname version meta;
      rtp = "${wrapped}/share/tmux-plugins/tmux-window-name/tmux_window_name.tmux";
      passthru = unwrapped.passthru or {};
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

  # tmux-powerkit requires runtime dependencies (uname, grep, awk, etc.)
  # We wrap all shell scripts with the necessary PATH
  tmux-powerkit = let
    unwrapped = pkgs.tmuxPlugins.mkTmuxPlugin {
      pluginName = "tmux-powerkit";
      version = "head";
      src = pkgs.fetchFromGitHub {
        owner = "fabioluciano";
        repo = "tmux-powerkit";
        rev = "9d5bfdaabf2a03e05d8ae11f1065f694d15df0d5";
        sha256 = "sha256-QhCUQDmt+Ur6KakrycJ4uvnIZzTHGkG/f01vslFxR5w=";
      };
    };
    runtimeDeps = with pkgs; [coreutils gnugrep gawk gnused findutils];
    runtimePath = lib.makeBinPath runtimeDeps;
    wrapped = pkgs.runCommand "tmux-powerkit-wrapped" {} ''
      cp -r ${unwrapped} $out
      chmod -R +w $out

      # Add PATH to all shell scripts
      for f in $(find $out -name "*.sh" -o -name "*.tmux"); do
        if [[ -f "$f" ]] && head -1 "$f" | grep -q "^#!.*bash"; then
          sed -i '2i export PATH="${runtimePath}:$PATH"' "$f"
        fi
      done
    '';
  in
    wrapped
    // {
      inherit (unwrapped) pname version meta;
      rtp = "${wrapped}/share/tmux-plugins/tmux-powerkit/tmux-powerkit.tmux";
      passthru = unwrapped.passthru or {};
    };

  tmux-file-picker-src = pkgs.fetchFromGitHub {
    owner = "raine";
    repo = "tmux-file-picker";
    rev = "0473f7abe87b95bc008e1cbfd16578e9cee93565";
    sha256 = "sha256-Uz+88f3RG7dBangOg0RLQxuE9f49TpMOcQkTtauzPQU=";
  };

  cfg = config.programs.tmux-plugins;
in {
  options.programs.tmux-plugins = {
    enable = lib.mkEnableOption "tmux plugins";
  };

  config = lib.mkIf cfg.enable {
    _module.args = {
      inherit tmux-window-name tmux-fzf-head tmux-nested tmux-fuzzback tmux-powerkit;
    };

    programs.tmux = {
      enable = true;
      keyMode = "vi";
      clock24 = true;
      mouse = true;
      prefix = "C-Space";
      historyLimit = 20000;
      baseIndex = 1;
      aggressiveResize = true;
      # escapeTime = 0;
      terminal = "screen-256color";

      plugins = with pkgs.tmuxPlugins; [
        gruvbox
        tmux-colors-solarized
        fzf-tmux-url
        tmux-fzf-head
        {
          plugin = fingers;
          extraConfig = ''
            set -g @fingers-show-copied-notification 0
            ${lib.optionalString pkgs.stdenv.isLinux ''
              # Use OSC52 for clipboard on Linux (works through SSH/nested tmux)
              set -g @fingers-main-action '${localPackages.osc52-copy}/bin/osc52-copy'
            ''}
          '';
        }
        extrakto
        {
          plugin = tmux-window-name;
        }
        {
          plugin = tmux-powerkit;
        }
      ];
      extraConfig = lib.mkAfter ''
        if-shell "uname | grep -q Darwin" {
          set-option -g default-command "reattach-to-user-namespace -l zsh"
        }

        # Bring these environment variables into tmux on re-attach
        set-option -g update-environment "SSH_AUTH_SOCK SSH_CONNECTION DISPLAY REMOTE_BROWSER_PORT"

        ${lib.optionalString pkgs.stdenv.isLinux ''
          # Use xdg-open-remote for fzf-tmux-url plugin (opens URLs on Mac via SSH tunnel)
          set -g @fzf-url-open '${localPackages.xdg-open-remote}/bin/xdg-open-remote'
        ''}

        # Vim style pane selection
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        # Need to decide if these are the commands I want to use
        bind "C-h" select-pane -L
        bind "C-j" select-pane -D
        bind "C-k" select-pane -U
        bind "C-l" select-pane -R

        # Recommended for sesh
        bind-key x kill-pane # skip "kill-pane 1? (y/n)" prompt
        set -g detach-on-destroy off  # don't exit from tmux when closing a session
        bind -N "last-session (via sesh) " L run-shell "sesh last"

        bind -n "M-k" run-shell "sesh connect \"$(
            sesh list --icons | fzf-tmux -p 80%,70% --no-border \
              --reverse \
              --ansi \
              --list-border \
              --no-sort --prompt '⚡  ' \
              --color 'list-border:6,input-border:3,preview-border:2,header-bg:-1,header-border:6' \
              --input-border \
              --header-border \
              --bind 'tab:down,btab:up' \
              --bind 'ctrl-a:change-prompt(⚡  )+reload(sesh list --icons)' \
              --bind 'ctrl-t:change-prompt(🪟  )+reload(sesh list -t --icons)' \
              --bind 'ctrl-g:change-prompt(⚙️  )+reload(sesh list -c --icons)' \
              --bind 'ctrl-x:change-prompt(📁  )+reload(sesh list -z --icons)' \
              --bind 'ctrl-f:change-prompt(🔎  )+reload(fd -H -d 2 -t d -E .Trash . ~)' \
              --bind 'ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list --icons)' \
              --preview-window 'right:70%' \
              --preview 'sesh preview {}' \
        )\""

        # set-option -g status-position top
        set -g renumber-windows on
        set -g set-clipboard on
        set -g allow-passthrough all  # Allow OSC52 clipboard through nested tmux/SSH (all panes, not just active)

        # Status left configuration:
        # - #[bg=colour241,fg=colour248]: Sets grey background with light text
        # - Second #[...]: Configures separator styling
        # - #S: Displays current session name
        set-option -g status-left "#[bg=colour241,fg=colour46] #S #[bg=colour237,fg=colour241,nobold,noitalics,nounderscore]"

        # Status right configuration:
        # - First #[...]: Sets up transition styling
        # - %Y-%m-%d: Shows date in YYYY-MM-DD format
        # - %H:%M: Shows time in 24-hour format
        # - #h: Displays hostname
        # - Second #[...]: Configures styling for session name

        # set-option -g status-right "#[bg=colour237,fg=colour239 nobold, nounderscore, noitalics]#[bg=colour239,fg=colour246] %Y-%m-%d  %H:%M #[bg=colour239,fg=colour248,nobold,noitalics,nounderscore]#[bg=colour248,fg=colour237] #h "

        # better windown focus styling, need to make this closer to the current color scheme
        set-window-option -g window-style 'bg=#1A1B26'
        set-window-option -g window-active-style 'bg=#011627'
        set -g pane-border-style 'fg=colour238,bg=#101010'
        set -g pane-active-border-style 'fg=colour113,bg=#151515'

        # Per session kubeconfig
        set-hook -g session-created 'run-shell "~/.config/tmux/cp-kubeconfig start #{hook_session_name}"'
        set-hook -g session-closed 'run-shell "~/.config/tmux/cp-kubeconfig stop #{hook_session_name}"'

        # https://github.com/samoshkin/tmux-config/blob/master/tmux/tmux.conf
        set -g buffer-limit 20
        set -g display-time 1500
        set -g remain-on-exit off
        set -g repeat-time 300
        # setw -g allow-rename off
        # setw -g automatic-rename off

        # Turn off the prefix key when nesting tmux sessions, led to this
        # https://gist.github.com/samoshkin/05e65f7f1c9b55d3fc7690b59d678734?permalink_comment_id=4616322#gistcomment-4616322
        # Whcih led to the tmux-nested plugin

        # keybind to disable outer-most active tmux
        set -g @nested_down_keybind 'M-o'
        # keybind to enable inner-most inactive tmux
        set -g @nested_up_keybind 'M-O'
        # keybind to recursively enable all tmux instances
        set -g @nested_up_recursive_keybind 'M-U'
        # status style of inactive tmux
        set -g @nested_inactive_status_style '#[fg=black,bg=red] #h #[bg=colour237,fg=colour241,nobold,noitalics,nounderscore]'
        set -g @nested_inactive_status_style_target 'status-left'

        # tmux-powerkit configuration
        set -g @powerkit_theme 'tokyo-night'
        set -g @powerkit_theme_variant 'night'
        set -g @powerkit_plugins 'datetime,battery,cpu,memory,git,kubernetes'
        set -g @powerkit_session_icon 'auto'
        set -g @powerkit_transparent 'true'
        set -g @powerkit_options_key 'P'

        bind-key "C-f" run-shell -b "${tmux-fzf-head}/share/tmux-plugins/tmux-fzf/scripts/session.sh switch"
        run-shell ${tmux-nested}/share/tmux-plugins/tmux-nested/nested.tmux
        run-shell ${tmux-fuzzback}/share/tmux-plugins/tmux-fuzzback/fuzzback.tmux
        run-shell ${tmux-powerkit}/share/tmux-plugins/tmux-powerkit/tmux-powerkit.tmux

        # tmux-file-picker keybindings
        bind C-f display-popup -E "${tmux-file-picker-src}/tmux-file-picker"

        bind-key C-g display-popup -E "${tmux-file-picker-src}/tmux-file-picker -g"
        bind-key C-d display-popup -E "${tmux-file-picker-src}/tmux-file-picker --directories"
        bind-key C-z display-popup -E "${tmux-file-picker-src}/tmux-file-picker --zoxide"
        bind-key C-v display-popup -E "${tmux-file-picker-src}/tmux-file-picker --zoxide --dir-only"
        bind-key C-x display-popup -E "${tmux-file-picker-src}/tmux-file-picker --zoxide --git-root"

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
