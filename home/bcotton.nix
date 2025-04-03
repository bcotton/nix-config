{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: let
  nixVsCodeServer = fetchTarball {
    url = "https://github.com/zeyugao/nixos-vscode-server/tarball/master";
    sha256 = "sha256:0p0dz0q1rbccncjgw4na680a5i40w59nbk5ip34zcac8rg8qx381";
  };
in {
  home.stateVersion = "23.05";

  imports = [
    "${nixVsCodeServer}/modules/vscode-server/home.nix"
  ];

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
      export GOPATH=$HOME/go
      export GOPRIVATE="github.com/grafana/*"
      export LESS="-iMSx4 -FXR"
      export OKTA_MFA_OPTION=1
      export PAGER=less
      export PATH=$GOPATH/bin:/opt/homebrew/share/google-cloud-sdk/bin:~/projects/deployment_tools/scripts/gcom:~/projects/grafana-app-sdk/target:$PATH
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

    initExtra = ''
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
      [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

      if [ -e "/var/run/user/1000/podman/podman.sock" ]; then
         export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock
         export DOCKER_BUILDKIT=0
      fi

      [ -e ~/.config/sensitive/.zshenv ] && \. ~/.config/sensitive/.zshenv

      source <(kubectl completion zsh)
      eval "$(tv init zsh)"
      eval "$(atuin init zsh --disable-up-arrow)"
      eval "$(zoxide init zsh)"

      bindkey -e
      bindkey '^[[A' up-history
      bindkey '^[[B' down-history
      #bindkey -M
      bindkey '\M-\b' backward-delete-word
      bindkey -s "^Z" "^[Qls ^D^U^[G"
      bindkey -s "^X^F" "e "

      setopt autocd autopushd autoresume cdablevars correct correctall extendedglob globdots histignoredups longlistjobs mailwarning  notify pushdminus pushdsilent pushdtohome rcquotes recexact sunkeyboardhack menucomplete always_to_end hist_allow_clobber no_share_history
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
    unstablePkgs.aider-chat
    devenv
    fx
    kubernetes-helm
    kubectx
    kubectl
    llm
    nodejs_22
    opentofu
    unstablePkgs.sesh
    unstablePkgs.uv
    # TODO: write an overlay for this or use the flake
    # unstablePkgs.ghostty
    tldr
    unstablePkgs.spotdl
    unstablePkgs.zed-editor
  ];
}
