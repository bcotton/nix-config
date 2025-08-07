{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: let
  nixVsCodeServer = fetchTarball {
    url = "https://github.com/zeyugao/nixos-vscode-server/tarball/master";
    sha256 = "sha256:1l77kybmghws3y834b1agb69vs6h4l746ga5xccvz4p1y8wc67h7";
  };
in {
  home.stateVersion = "23.05";

  imports = [
    "${nixVsCodeServer}/modules/vscode-server/home.nix"
    ./modules/atuin.nix
    ./modules/tmux-plugins.nix
    ./modules/beets.nix
    # ./modules/sesh.nix
  ];

  programs.beets-cli.enable = true;
  programs.tmux-plugins.enable = true;

  # programs.sesh-config = {
  #   enable = true;
  #   sessions = [
  #     {
  #       name = "default";
  #     }
  #     {
  #       name = "just";
  #       startup_command = "cd ~/nix-config && just";
  #     }
  #     {
  #       name = "admin";
  #       startup_command = "ssh admin -t 'tmux a'";
  #     }
  #     {
  #       name = "nix-03";
  #       startup_command = "ssh -q nix-03 -L 10350:localhost:10350 -L 3000:localhost:3000  -t 'tmux a'";
  #     }
  #   ];
  # };

  programs.atuin-config = {
    enable-daemon = true;
    nixosKeyPath = "/run/agenix/bcotton-atuin-key";
    darwinKeyPath = "~/.local/share/atuin/key";
    filter_mode = "session";
  };

  # list of programs
  # https://mipmip.github.io/home-manager-option-search

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.fzf = {
    package = unstablePkgs.fzf;
    enable = true;
    enableZshIntegration = true;
    tmux.enableShellIntegration = true;
  };

  programs.git = {
    enable = true;
    userEmail = "bob.cotton@gmail.com";
    userName = "Bob Cotton";
    extraConfig = {
      alias = {
        br = "branch";
        co = "checkout";
        ci = "commit";
        d = "diff";
        dc = "diff --cached";
        st = "status";
        la = "config --get-regexp alias";
        lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%C(bold blue)<%an>%Creset' --abbrev-commit";
        lga = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%C(bold blue)<%an>%Creset' --abbrev-commit --all";
      };
      url = {
        "ssh://git@github.com/" = {
          insteadOf = "https://github.com/";
        };
      };
      init.defaultBranch = "main";
      pager.difftool = true;

      core = {
        whitespace = "trailing-space,space-before-tab";
        # pager = "difftastic";
      };
      # interactive.diffFilter = "difft";
      merge.conflictstyle = "diff3";
      diff = {
        # tool = "difftastic";
        colorMoved = "default";
      };
      # difftool."difftastic".cmd = "difft $LOCAL $REMOTE";
    };
    difftastic = {
      enable = false;
      background = "dark";
      display = "side-by-side";
    };
    includes = [
      {path = "${pkgs.delta}/share/themes.gitconfig";}
    ];
    delta = {
      enable = true;
      options = {
        # decorations = {
        #   commit-decoration-style = "bold yellow box ul";
        #   file-decoration-style = "none";
        #   file-style = "bold yellow ul";
        # };
        # features = "mellow-barbet";
        features = "collared-trogon";
        # whitespace-error-style = "22 reverse";
        navigate = true;
        light = false;
        side-by-side = true;
      };
    };
  };

  programs.htop = {
    enable = true;
    settings.show_program_path = true;
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
    extraConfig = ''
      if-shell "uname | grep -q Darwin" {
        set-option -g default-command "reattach-to-user-namespace -l zsh"
      }

      # Bring these environment variables into tmux on re-attach
      set-option -g update-environment "SSH_AUTH_SOCK SSH_CONNECTION DISPLAY"

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
          ~/go/bin/sesh list --icons | fzf-tmux -p 80%,70% --no-border \
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
            --preview '~/go/bin/sesh preview {}' \
      )\""

      # set-option -g status-position top
      set -g renumber-windows on
      set -g set-clipboard on

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
      set-option -g status-right "#[bg=colour237,fg=colour239 nobold, nounderscore, noitalics]#[bg=colour239,fg=colour246] %Y-%m-%d  %H:%M #[bg=colour239,fg=colour248,nobold,noitalics,nounderscore]#[bg=colour248,fg=colour237] #h "

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

      # tmux-fzf stuff

      # git-popup: (<prefix> + ctrl-g)
      bind-key C-g display-popup -E -d "#{pane_current_path}" -xC -yC -w 80% -h 75% "lazygit"
      # k9s popup: (<prefix> + ctrl-k)
      bind-key C-k display-popup -E -d "#{pane_current_path}" -xC -yC -w 80% -h 75% "k9s"
      # jq as a popup, from the clipboard
      bind-key C-j display-popup -E -d "#{pane_current_path}" -xC -yC -w 80% -h 75% "pbpaste | jq -C '.' | less -R"
      # btop as a popup
      bind-key C-b display-popup -E -d "#{pane_current_path}" -xC -yC -w 80% -h 75% "btop"


    '';
  };

  services.vscode-server.enable = true;
  services.vscode-server.installPath = [
    "$HOME/.vscode-server"
    "$HOME/.cursor-server"
  ];

  home.file."oh-my-zsh-custom" = {
    enable = true;
    source = ./oh-my-zsh-custom;
    target = ".oh-my-zsh-custom";
  };

  xdg = {
    enable = true;
    configFile."containers/registries.conf" = {
      source = ./dot.config/containers/registries.conf;
    };
    configFile."ghostty/config" = {
      source = ./bcotton.config/ghostty/config;
    };
    configFile."sesh/sesh.toml" = {
      source = ./bcotton.config/sesh/sesh.toml;
    };
    configFile."tmux/cp-kubeconfig" = {
      executable = true;
      source = ./bcotton.config/tmux/cp-kubeconfig;
    };
    configFile."nix/registry.json" = {
      source = ./bcotton.config/nix/registry.json;
    };
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    defaultKeymap = "emacs";
    autocd = true;

    cdpath = [
      "."
      ".."
      "../.."
      "~"
      "~/projects"
    ];

    dirHashes = {
      docs = "$HOME/Documents";
      proj = "$HOME/projects";
      dl = "$HOME/Downloads";
    };

    # atuin register -u bcotton -e bob.cotton@gmail.com
    envExtra = ''
      #export DOCKER_HOST="unix://$HOME/.docker/run/docker.sock"
      export BAT_THEME="Visual Studio Dark+"
      export DFT_DISPLAY=side-by-side
      export EDITOR=vim
      export EMAIL=bob.cotton@gmail.com
      export EXA_COLORS="da=1;35"
      export FULLNAME='Bob Cotton'
      export GOPATH=$HOME/projects/go
      export GOPRIVATE="github.com/grafana/*"
      export LESS="-iMSx4 -FXR"
      export OKTA_MFA_OPTION=1
      export PAGER=less
      export PATH=$GOPATH/bin:/opt/homebrew/sbin:/opt/homebrew/share/google-cloud-sdk/bin:~/projects/deployment_tools/scripts/gcom:~/projects/grafana-app-sdk/target:$PATH
      export QMK_HOME=~/projects/qmk_firmware
      export TMPDIR=/tmp/
      export XDG_CONFIG_HOME="$HOME/.config"

      export FZF_CTRL_R_OPTS="--reverse"
      export FZF_TMUX_OPTS="-p"

      export ZSH_AUTOSUGGEST_STRATEGY=(history completion)

      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
      [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

      if [ -e "/var/run/user/1000/podman/podman.sock" ]; then
         export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock
         export DOCKER_BUILDKIT=0
      fi



      [ -e ~/.config/sensitive/.zshenv ] && \. ~/.config/sensitive/.zshenv
    '';

    oh-my-zsh = {
      enable = true;
      custom = "$HOME/.oh-my-zsh-custom";

      theme = "git-taculous";
      # theme = "agnoster-nix";

      extraConfig = ''
        zstyle :omz:plugins:ssh-agent identities id_ed25519
        if [[ `uname` == "Darwin" ]]; then
          zstyle :omz:plugins:ssh-agent ssh-add-args --apple-load-keychain
        fi
        source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
      '';
      plugins = [
        "brew"
        "bundler"
        "colorize"
        "dotenv"
        "fzf"
        "git"
        "gh"
        "kubectl"
        "kube-ps1"
        "ssh-agent"
        "tmux"

        # these are custom
        "kubectl-fzf-get"
        "git-reflog-fzf"
        "sesh"
        "rgf-search"
        "gwt"
      ];
    };

    shellAliases = {
      # Automatically run `go test` for a package when files change.
      autotest = "watchexec -c clear -o do-nothing --delay-run 100ms --exts go 'pkg=\".\${WATCHEXEC_COMMON_PATH/\$PWD/}/...\"; echo \"running tests for \$pkg\"; go test \"\$pkg\"'";
      cd = "z";
      batj = "bat -l json";
      batly = "bat -l yaml";
      batmd = "bat -l md";
      dir = "exa -l --icons --no-user --group-directories-first  --time-style long-iso --color=always";
      gdn = "git diff | gitnav";
      k = "kubectl";
      kctx = "kubectx";
      kns = "kubens";
      ltr = "ll -snew";
      tf = "tofu";
      tree = "exa -Tl --color=always";
      # watch = "watch --color "; # Note the trailing space for alias expansion https://unix.stackexchange.com/questions/25327/watch-command-alias-expansion
      watch = "viddy ";
      # z = "zoxide";
    };

    initContent = ''
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
      [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

      if [ -e "/var/run/user/1000/podman/podman.sock" ]; then
         export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock
         export DOCKER_BUILDKIT=0
      fi

      [ -e ~/.config/sensitive/.zshenv ] && \. ~/.config/sensitive/.zshenv

      source <(kubectl completion zsh)
      eval "$(atuin init zsh --disable-up-arrow)"
      eval "$(zoxide init zsh)"

      bindkey -e
      bindkey '^[[A' up-history
      bindkey '^[[B' down-history
      #bindkey -M
      bindkey '\M-\b' backward-delete-word
      bindkey -s "^Z" "^[Qls ^D^U^[G"
      bindkey -s "^X^F" "e "

      # This is the environment injection for sesh. Extract the env from the running
      # tmux prior to running any command.
      if [ -n "$TMUX" ]; then
        function refresh {
          export $(tmux show-environment | grep "^SSH_AUTH_SOCK") > /dev/null
          export $(tmux show-environment | grep "^DISPLAY") > /dev/null
          export $(tmux show-environment | grep "^KUBECONFIG") > /dev/null
        }
      else
        function refresh { }
      fi

      function preexec {
         refresh
      }



      # Advanced customization of fzf options via _fzf_comprun function
      # - The first argument to the function is the name of the command.
      # - You should make sure to pass the rest of the arguments ($@) to fzf.
      _fzf_comprun() {
        local command=$1
        shift

        case "$command" in
          cd)           fzf --preview 'exa -Tl --color=always {}'  "$@" ;;
          z)            fzf --preview 'exa -Tl --color=always {}'  "$@" ;;
          export|unset) fzf --preview "eval 'echo \$'{}"           "$@" ;;
          ssh)          fzf --preview 'dig {}'                     "$@" ;;
          *)            fzf --preview 'bat -n --color=always {}'   "$@" ;;
        esac
      }

      # nix shell nixpkgs#pacakge and 'nix run' and the proper channel-less way to bring in a program
      function nix-run () {
        program="$1"
        shift
        nix run "nixpkgs#$program" -- "$@"
      }

      function nix-run-unstable () {
        program="$1"
        shift
        nix run "nixpkgs-unstable#$program" -- "$@"
      }

      if [[ "$TERM_PROGRAM" != "vscode" ]]; then
        RPROMPT=$RED'[%~]'$DEFAULT
        DISABLE_AUTO_UPDATE="true"
        DISABLE_UPDATE_PROMPT="true"
      fi

      setopt autocd autopushd autoresume cdablevars correct correctall extendedglob histignoredups longlistjobs mailwarning  notify pushdminus pushdsilent pushdtohome rcquotes recexact sunkeyboardhack always_to_end hist_allow_clobber no_share_history
      unsetopt menucomplete
      unset globdots
      unsetopt bgnice

    '';
  };

  programs.home-manager.enable = true;
  programs.eza.enable = true;

  #  programs.neovim.enable = true;
  programs.nix-index.enable = true;
  programs.zoxide.enable = true;

  programs.ssh = {
    enable = true;
    extraConfig = ''
      Host *
        StrictHostKeyChecking no
        ForwardAgent yes

      Host github.com
        Hostname ssh.github.com
        Port 443
    '';
    matchBlocks = {
    };
  };

  home.packages = with pkgs; [
    (pkgs.python312.withPackages (ppkgs: [
      ppkgs.libtmux
    ]))
    unstablePkgs.aider-chat
    devenv
    fx
    kubernetes-helm
    kubectx
    kubectl
    llm
    # nodejs_22
    opentofu
    unstablePkgs.sesh
    unstablePkgs.uv
    tldr
    unstablePkgs.spotdl
    unstablePkgs.zed-editor
  ];
}
