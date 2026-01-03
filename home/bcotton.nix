{
  config,
  pkgs,
  lib,
  unstablePkgs,
  hostName ? "unknown",
  workmuxPackage,
  inputs,
  ...
}: let
  nixVsCodeServer = fetchTarball {
    url = "https://github.com/zeyugao/nixos-vscode-server/tarball/master";
    sha256 = "sha256:1l77kybmghws3y834b1agb69vs6h4l746ga5xccvz4p1y8wc67h7";
  };
in {
  home.stateVersion = "23.05";

  imports = let
    # Create the path to the host-specific config file
    # We use string interpolation here because hostName is available as a function argument
    hostConfigFile = "bcotton-hosts/${hostName}.nix";
    hostConfigPath = ./. + "/${hostConfigFile}";
  in
    [
      "${nixVsCodeServer}/modules/vscode-server/home.nix"
      ./modules/atuin.nix
      ./modules/tmux-plugins.nix
      ./modules/beets.nix
      ./modules/hyprland
      ./modules/gwtmux.nix
      ./modules/zsh-profiling.nix
      ./modules/kubectl-lazy.nix
      ./modules/nvm-lazy.nix
      # workmux module is imported via flake input in flake.nix
      # ./modules/sesh.nix
    ]
    ++ lib.optional (builtins.pathExists hostConfigPath) hostConfigPath;

  # Beets is only available on Linux due to gst-python build issues on Darwin
  programs.beets-cli.enable = pkgs.stdenv.isLinux;
  programs.tmux-plugins.enable = true;
  programs.gwtmux.enable = true;

  # Hyprland configuration - these are default settings
  # Host-specific overrides can be placed in bcotton-hosts/<hostname>.nix
  # See bcotton-hosts/README.md for details on per-host configuration
  # Using lib.mkDefault allows host-specific configs to override these values
  programs.hyprland-config = {
    enable = lib.mkDefault false;
    modifier = lib.mkDefault "SUPER";
    terminal = lib.mkDefault "ghostty";
    browser = lib.mkDefault "firefox";
    # Default monitor auto-configuration
    monitors = lib.mkDefault [
      ",preferred,auto,auto"
    ];
    gapsIn = lib.mkDefault 5;
    gapsOut = lib.mkDefault 10;
  };

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

  programs.workmux = {
    enable = true;
    package = workmuxPackage;
    agent = "claude";
    mainBranch = "main";
    worktreeDir = "..";
    windowPrefix = "";
    mergeStrategy = "merge";

    panes = [
      {
        command = "<agent>";
        focus = true;
      }
      {
        split = "horizontal";
      }
    ];
  };

  programs.atuin-config = {
    enable-daemon = true;
    nixosKeyPath = "/run/agenix/bcotton-atuin-key";
    darwinKeyPath = "~/.local/share/atuin/key";
    filter_mode = "session";
  };

  # ZSH performance optimizations
  programs.zsh-profiling.enable = false; # Enable to see zprof output on shell startup
  programs.kubectl-lazy.enable = true; # Step 2: Enable kubectl lazy-loading
  programs.nvm-lazy.enable = true; # Step 3: Enable NVM lazy-loading

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
        clone-gwt = "!sh $HOME/.config/git-worktrees/git-clone-bare-for-worktrees.sh";
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
    configFile."git-worktrees/git-clone-bare-for-worktrees.sh" = {
      executable = true;
      source = ./bcotton.config/git-worktrees/git-clone-bare-for-worktrees.sh;
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
      export PNPM_HOME="$HOME/.local/share/pnpm"
      export PATH="$PNPM_HOME:$PATH"
      export PATH=$GOPATH/bin:/opt/homebrew/sbin:/opt/homebrew/share/google-cloud-sdk/bin:~/projects/deployment_tools/scripts/gcom:~/projects/grafana-app-sdk/target:$PATH
      export QMK_HOME=~/projects/qmk_firmware
      export TMPDIR=/tmp/
      export XDG_CONFIG_HOME="$HOME/.config"

      export FZF_CTRL_R_OPTS="--reverse"
      export FZF_TMUX_OPTS="-p"

      export ZSH_AUTOSUGGEST_STRATEGY=(history completion)

      # Fix the docker host for podman on nix-03
      # if the symlink at $HOME/.config/systemd/user/podman.service is broken, rm it
      # This sould only run on linux hosts
      if [ -L "$HOME/.config/systemd/user/podman.service" ] && [ "$(uname)" = "Linux" ]; then
        echo "Fixing podman.service"
        systemctl --user enable podman.socket
        systemctl --user start podman.socket
      fi

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
        "claude-personal"
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
      wm = "workmux";
    };

    initContent = ''
      # Source zsh-defer for deferred initialization
      source ${pkgs.zsh-defer}/share/zsh-defer/zsh-defer.plugin.zsh

      # Defer heavy initializations until after prompt displays
      zsh-defer -c 'eval "$(atuin init zsh --disable-up-arrow)"'

      if [[ "$CLAUDECODE" != "1" ]]; then
        zsh-defer -c 'eval "$(zoxide init zsh)"; alias cd="z"'
      fi

      zsh-defer -c 'eval "$(sesh completion zsh)"'

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
      Host nas-01 nix-02 nix-03
        IdentityFile ~/.ssh/nix-builder-id_ed25519
        IdentitiesOnly no

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
    # unstablePkgs.aider-chat
    bottom
    claude-code
    devenv
    fx
    kubernetes-helm
    kubectx
    kubectl
    unstablePkgs.llm
    # nodejs_22
    opentofu

    inputs.opencode.packages.${pkgs.system}.default

    procs
    unstablePkgs.sesh
    unstablePkgs.uv
    tldr
    #  unstablePkgs.spotdl
    unstablePkgs.zed-editor
    zsh-defer # Step 4: Needed for deferred initialization
  ];
}
