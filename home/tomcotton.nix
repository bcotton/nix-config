{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: let
  # See https://haseebmajid.dev/posts/2023-07-10-setting-up-tmux-with-nix-home-manager/
  tmux-window-name =
    pkgs.tmuxPlugins.mkTmuxPlugin
    {
      pluginName = "tmux-window-name";
      version = "head";
      src = pkgs.fetchFromGitHub {
        owner = "bcotton";
        repo = "tmux-window-name";
        rev = "0bb0148623782dbfb5c15741111f0402609f516f";
        sha256 = "sha256-xb0GGBZ4Ox3LQjKZJ8MzJluElxRJm3BB73F2CMFJEa0=";
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
  nixVsCodeServer = fetchTarball {
    url = "https://github.com/msteen/nixos-vscode-server/tarball/master";
    sha256 = "sha256:09j4kvsxw1d5dvnhbsgih0icbrxqv90nzf0b589rb5z6gnzwjnqf";
  };
in {
  home.stateVersion = "24.05";

  # list of programs
  # https://mipmip.github.io/home-manager-option-search

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    tmux.enableShellIntegration = true;
  };

  programs.git = {
    enable = true;
    userEmail = "thomaswileycotton@gmail.com";
    userName = "wileycotton";
    extraConfig = {
      alias = {
        # br = "branch";
        # co = "checkout";
        # ci = "commit";
        # d = "diff";
        # dc = "diff --cached";
        gs = "status";
        # la = "config --get-regexp alias";
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
    # difftastic = {
    #   enable = false;
    #   background = "dark";
    #   display = "side-by-side";
    # };
    includes = [
      {path = "${pkgs.delta}/share/themes.gitconfig";}
    ];
    # delta = {
    #   enable = true;
    #   options = {
    #     # decorations = {
    #     #   commit-decoration-style = "bold yellow box ul";
    #     #   file-decoration-style = "none";
    #     #   file-style = "bold yellow ul";
    #     # };
    #     # features = "mellow-barbet";
    #     features = "collared-trogon";
    #     # whitespace-error-style = "22 reverse";
    #     navigate = true;
    #     light = false;
    #     side-by-side = true;
    #   };
    # };
  };

  programs.htop = {
    enable = true;
    settings.show_program_path = true;
  };

  programs.tmux = {
    enable = true;
    keyMode = "vi"; # Seems fine? May mess with keybindings
    clock24 = true;
    mouse = true;
    prefix = "C-b";
    historyLimit = 20000;
    baseIndex = 1;
    aggressiveResize = true;
    # escapeTime = 0;
    terminal = "screen-256color";
    plugins = with pkgs.tmuxPlugins; [
      gruvbox
      tmux-colors-solarized

      # Default: <prefix> + u - show and open urls
      fzf-tmux-url

      # Run the latest tmux-fzf
      tmux-fzf-head

      # Default <prefix> + space - show a list of things to copy
      tmux-thumbs
      {
        plugin = tmux-window-name;
      }
    ];
    extraConfig = ''
      new-session -s main
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


      bind-key "C-f" run-shell -b "${tmux-fzf-head}/share/tmux-plugins/tmux-fzf/scripts/session.sh switch"

      # set-option -g status-position top
      set -g renumber-windows on
      set -g set-clipboard on

      set-option -g status-left "#[bg=colour241,fg=colour248] #h #[bg=colour237,fg=colour241,nobold,noitalics,nounderscore]"
      set-option -g status-right "#[bg=colour237,fg=colour239 nobold, nounderscore, noitalics]#[bg=colour239,fg=colour246] %Y-%m-%d  %H:%M #[bg=colour239,fg=colour248,nobold,noitalics,nounderscore]#[bg=colour248,fg=colour237] #S "


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
      set -g @nested_inactive_status_style '#[fg=black,bg=red] #h #[bg=colour237,fg=colour241,nobold,noitalics,nounderscore]'
      set -g @nested_inactive_status_style_target 'status-left'

      # The above setting need to be set before running the nested.tmux script
      run-shell ${tmux-nested}/share/tmux-plugins/tmux-nested/nested.tmux

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

  imports = [
    "${nixVsCodeServer}/modules/vscode-server/home.nix"
  ];
  services.vscode-server.enable = true;
  services.vscode-server.installPath = "$HOME/.vscode-server";

  # TODO: add ~/bin
  # code --remote ssh-remote+<remoteHost> <remotePath>

  home.file."oh-my-zsh-custom" = {
    enable = true;
    source = ./oh-my-zsh-custom;
    target = ".oh-my-zsh-custom";
  };

  home.file.".config/karabiner" = {
    enable = true;
    force = true;
    source = tomcotton.config/karabiner.json;
    target = ".config/karabiner/karabiner.json";
  };

  xdg = {
    enable = true;
    configFile."containers/registries.conf" = {
      source = ./dot.config/containers/registries.conf;
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
      vdocs = "/Volumes/Files_Tom/Documents";
      dl = "$HOME/Downloads";
    };

    # Environment variables
    envExtra = ''
      export DFT_DISPLAY=side-by-side
      export XDG_CONFIG_HOME="$HOME/.config"
      export LESS="-iMSx4 -FXR"
      export PAGER=less
      export EDITOR=nano
      export FULLNAME='Thomas Wiley Cotton'
      export EMAIL=thomaswileycotton@gmail.com
      export GOPATH=$HOME/go
      export PATH=$GOPATH/bin:$PATH

      export EXA_COLORS="da=1;35"
      export BAT_THEME="Visual Studio Dark+"
      export TMPDIR=/tmp/

      export FZF_CTRL_R_OPTS="--reverse"
      export FZF_TMUX_OPTS="-p"

      export ZSH_AUTOSUGGEST_STRATEGY=(history completion)

      [ -e ~/.config/sensitive/.zshenv ] && \. ~/.config/sensitive/.zshenv   # Manual env variables not to be checked in
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
        "z"
      ];
    };

    shellAliases = {
      batj = "bat -l json";
      batly = "bat -l yaml";
      batmd = "bat -l md";
      dir = "exa -l --icons --no-user --group-directories-first  --time-style long-iso --color=always";
      ltr = "ll -snew";
      tree = "exa -Tl --color=always";
      # watch = "watch --color "; # Note the trailing space for alias expansion https://unix.stackexchange.com/questions/25327/watch-command-alias-expansion
      watch = "viddy ";
      # Automatically run `go test` for a package when files change.
      py3 = "python3";
    };

    initExtra = ''
      tmux-window-name() {
        (${builtins.toString tmux-window-name}/share/tmux-plugins/tmux-window-name/scripts/rename_session_windows.py &)
      }
      if [[ `uname` == "Darwin" ]]; then
        add-zsh-hook chpwd tmux-window-name
      fi

      bindkey -e
      bindkey '^[[A' up-history
      bindkey '^[[B' down-history
      #bindkey -m
      bindkey '\M-\b' backward-delete-word
      bindkey -s "^Z" "^[Qls ^D^U^[G"
      bindkey -s "^X^F" "e "

      setopt autocd autopushd autoresume cdablevars correct correctall extendedglob globdots histignoredups longlistjobs mailwarning  notify pushdminus pushdsilent pushdtohome rcquotes recexact sunkeyboardhack menucomplete always_to_end hist_allow_clobber no_share_history
      unsetopt bgnice


    '';

    #initExtra = (builtins.readFile ../mac-dot-zshrc);
  };

  programs.eza.enable = true;
  programs.home-manager.enable = true;
  #  programs.neovim.enable = true;
  programs.nix-index.enable = true;
  #  programs.zoxide.enable = true;

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
    ffmpeg
    rsync
    rhash
    restic
    # kubernetes-helm
    # kubectx
    # kubectl
    #   ## unstable
    #   unstablePkgs.yt-dlp
    #   unstablePkgs.terraform

    #   ## stable
    #   ansible
    #   asciinema
    #   bitwarden-cli
    #   coreutils
    #   # direnv # programs.direnv
    #   #docker
    #   drill
    #   du-dust
    #   dua
    #   duf
    #   esptool
    #   ffmpeg
    #   fd
    #   #fzf # programs.fzf
    #   #git # programs.git
    gh
    #   go
    #   gnused
    #   #htop # programs.htop
    #   hub
    #   hugo
    #   ipmitool
    #   jetbrains-mono # font
    #   just
    #   jq
    #   mas # mac app store cli
    #   mc
    #   mosh
    #   neofetch
    #    nmap
    #      (python311.withPackages(ps: with ps; [ libtmux ]))
    #   ripgrep
    #   skopeo
    #   smartmontools
    #   tree
    #   unzip
    #   watch
    #   wget
    #   wireguard-tools
  ];
}
