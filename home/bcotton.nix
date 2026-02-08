{
  config,
  pkgs,
  lib,
  unstablePkgs,
  hostName ? "unknown",
  nixosHosts ? [],
  workmuxPackage,
  crushPackage,
  inputs,
  ...
}: {
  home.stateVersion = "23.05";

  # Declarative PATH management - cross-platform paths
  home.sessionPath =
    [
      "$HOME/.local/bin"
      "$HOME/projects/deployment_tools/scripts/gcom"
      "$HOME/projects/grafana-app-sdk/target"
    ]
    # macOS-specific paths (Homebrew)
    ++ lib.optionals pkgs.stdenv.isDarwin [
      "/opt/homebrew/sbin"
      "/opt/homebrew/share/google-cloud-sdk/bin"
    ];

  imports = let
    # Create the path to the host-specific config file
    # We use string interpolation here because hostName is available as a function argument
    hostConfigFile = "bcotton-hosts/${hostName}.nix";
    hostConfigPath = ./. + "/${hostConfigFile}";
  in
    [
      inputs.vscode-server.homeModules.default
      ./modules/atuin.nix
      ./modules/git.nix
      ./modules/tmux-plugins.nix
      ./modules/beets.nix
      ./modules/hyprland
      ./modules/gwtmux.nix
      ./modules/llm.nix
      ./modules/zsh-profiling.nix
      ./modules/kubectl-lazy.nix
      ./modules/nvm-lazy.nix
      ./modules/tmux-popup-apps.nix
      ./modules/browser-opener.nix
      ./modules/clipboard-receiver.nix
      ./modules/notification-receiver.nix
      ./modules/xdg-open-remote.nix
      ./modules/remote-copy.nix
      ./modules/remote-notify.nix
      ./modules/arc-tab-archiver.nix
      # workmux module is imported via flake input in flake.nix
      # ./modules/sesh.nix
    ]
    ++ lib.optional (builtins.pathExists hostConfigPath) hostConfigPath;

  # Beets is only available on Linux due to gst-python build issues on Darwin
  programs.beets-cli.enable = pkgs.stdenv.isLinux;
  programs.tmux-plugins.enable = true;
  programs.gwtmux.enable = true;

  # Remote browser opening - allows CLI tools on remote Linux hosts to open
  # URLs in the browser on the local Mac desktop via SSH reverse port forwarding
  programs.browser-opener.enable = pkgs.stdenv.isDarwin;
  programs.xdg-open-remote.enable = pkgs.stdenv.isLinux;

  # Remote clipboard - allows remote Linux hosts to copy text to local Mac clipboard
  programs.clipboard-receiver.enable = pkgs.stdenv.isDarwin;
  programs.remote-copy.enable = pkgs.stdenv.isLinux;

  # Remote notifications - allows remote Linux hosts to send macOS notifications
  programs.notification-receiver.enable = pkgs.stdenv.isDarwin;
  programs.remote-notify.enable = pkgs.stdenv.isLinux;

  # Arc Tab Archiver - captures auto-archived Arc browser tabs to Obsidian
  programs.arc-tab-archiver = {
    enable = pkgs.stdenv.isDarwin;
    obsidianDir = "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Bob's Projects/arc-archive";
  };

  programs.tmux-popup-apps = {
    enable = true;
    apps = [
      {
        name = "LazyGit";
        command = "lazygit";
      }
      {
        name = "LazyDocker";
        command = "lazydocker";
      }
      {
        name = "K9s";
        command = "k9s";
      }
      {
        name = "Btop";
        command = "btop";
      }
      {
        name = "JQ Clipboard";
        command = "pbpaste | jq -C '.' | less -R";
      }
    ];
  };

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

  programs.llm = {
    enable = true;

    # Enable specific plugins
    plugins = {
      llm-anthropic = true; # Claude models
      llm-gemini = true; # Google Gemini models
      llm-openrouter = true; # OpenRouter models
      llm-jq = true; # jq plugin
      llm-openai-plugin = true; # OpenAI models
    };
  };

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

  programs.htop = {
    enable = true;
    settings.show_program_path = true;
  };

  # GitHub CLI with SSH protocol
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
    };
  };

  # Kubernetes dashboard
  programs.k9s = {
    enable = true;
  };

  # Command correction
  programs.thefuck = {
    enable = true;
    enableZshIntegration = true;
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
    configFile."beads-init/beads-init.sh" = {
      executable = true;
      source = ./bcotton.config/beads-init/beads-init.sh;
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
    envExtra =
      ''
        export BAT_PAGER="moar --mousemode=select"
        export BAT_STYLE="plain"
        export BAT_THEME="Visual Studio Dark+"
        export DFT_DISPLAY=side-by-side
        export MANPAGER="sh -c 'col -bx | bat -l man -p'"
        export MANROFFOPT="-c"
        export EDITOR=vim
        export EMAIL=bob.cotton@gmail.com
        export EXA_COLORS="da=1;35"
        export FULLNAME='Bob Cotton'
        export GOPATH=$HOME/projects/go
        export GOPRIVATE="github.com/grafana/*"
        export LESS="-iMSx4 -FXR"
        export OKTA_MFA_OPTION=1
        export PAGER=bat
        # Variable-dependent PATH additions (static paths are in home.sessionPath)
        export PNPM_HOME="$HOME/.local/share/pnpm"
        export PATH="$HOME/.orbstack/bin:$PNPM_HOME:$GOPATH/bin:$PATH"
        export QMK_HOME=~/projects/qmk_firmware
        export TILT_HOST=0.0.0.0
        export TMPDIR=/tmp/
        export XDG_CONFIG_HOME="$HOME/.config"

        export FZF_CTRL_R_OPTS="--reverse"
        export FZF_TMUX_OPTS="-p"

        export ZSH_AUTOSUGGEST_STRATEGY=(history completion)

        [ -e ~/.config/sensitive/.zshenv ] && \. ~/.config/sensitive/.zshenv
      ''
      # Linux-specific: podman socket configuration
      # TODO: The systemctl fix should ideally be in NixOS activation, not shell init
      + lib.optionalString pkgs.stdenv.isLinux ''
        # Fix broken podman.service symlink if present
        if [ -L "$HOME/.config/systemd/user/podman.service" ]; then
          systemctl --user enable podman.socket 2>/dev/null
          systemctl --user start podman.socket 2>/dev/null
        fi

        # Set DOCKER_HOST to use podman socket if available
        if [ -e "/var/run/user/1000/podman/podman.sock" ]; then
          export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock
          export DOCKER_BUILDKIT=0
        fi
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
        # "fzf" # Using programs.fzf.enableZshIntegration instead
        "git"
        "gh"
        "kubectl"
        "kube-ps1"
        "ssh-agent"
        "tmux"

        # these are custom
        "bd-completion"
        "bdl"
        "claude-personal"
        "kubectl-fzf-get"
        "git-reflog-fzf"
        "sesh"
        "rgf-search"
        "gwt"
      ];
    };

    shellAliases = {
      # Development
      autotest = "watchexec -c clear -o do-nothing --delay-run 100ms --exts go 'pkg=\".\${WATCHEXEC_COMMON_PATH/\$PWD/}/...\"; echo \"running tests for \$pkg\"; go test \"\$pkg\"'";
      claude-fork = "claude --fork-session --continue";
      claudep-fork = "claudep --fork-session --continue";
      gdn = "git diff | gitnav";
      lg = "lazygit";
      lgs = "lazygit status";
      ld = "lazydocker";
      tf = "tofu";
      wm = "workmux";

      # File viewing
      batj = "bat -l json";
      batl = "bat --style=numbers";
      batly = "bat -l yaml";
      batmd = "bat -l md";
      less = "bat";
      y = "yazi";
      dir = "exa -l --icons --no-user --group-directories-first  --time-style long-iso --color=always";
      tree = "exa -Tl --color=always";
      ltr = "ll -snew";
      watch = "viddy ";

      # Kubernetes
      k = "kubectl";
      kctx = "kubectx";
      kns = "kubens";
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
      zsh-defer -c 'eval "$($HOME/.local/bin/bd completion zsh)"; _bd_setup_completion'

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
          export $(tmux show-environment | grep "^REMOTE_BROWSER_PORT") > /dev/null
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

      # Wrapper for nix-shell that reminds about nix-run when using -p
      function nix-shell () {
        if [[ "$1" == "-p" ]]; then
          echo "💡 Tip: Use 'nix-run $2' instead of 'nix-shell -p $2'" >&2
        fi
        command nix-shell "$@"
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

      # Auto-page help output: detects --help or -h and pipes through pager
      # Uses bat with help syntax highlighting for colorized output
      # Also provides manual 'h' function: h git, h kubectl, etc.
      function h () {
        "$@" --help 2>&1 | bat -l help -p
      }

      # ZLE widget: auto-append pager when command ends with --help or -h
      function _auto_page_help() {
        # Check if command ends with --help, -h, or help (standalone)
        if [[ "$BUFFER" =~ '(--help|-h|[[:space:]]help)$' ]]; then
          # Don't double-pipe if already piped
          if [[ "$BUFFER" != *"|"* ]]; then
            # Save original command to history
            print -s "$BUFFER"
            # Prepend space so modified version isn't saved (HIST_IGNORE_SPACE)
            BUFFER=" $BUFFER 2>&1 | bat -l help -p"
          fi
        fi
        zle .accept-line
      }
      zle -N accept-line _auto_page_help

      # Reload home-manager environment after 'just switch'
      # Uses exec zsh to get a fresh shell with proper PATH initialization
      function reload-hm () {
        echo "🔄 Reloading home-manager environment..."

        # Reload tmux config first (before exec replaces this shell)
        if [[ -n "$TMUX" ]]; then
          local tmux_conf="$HOME/.config/tmux/tmux.conf"
          if [[ -f "$tmux_conf" ]]; then
            tmux source-file "$tmux_conf"
            echo "  ✓ Reloaded tmux.conf"
          fi
        fi

        # Unset the guard so hm-session-vars.sh runs in the new shell
        unset __HM_SESS_VARS_SOURCED

        echo "  ✓ Starting fresh shell..."
        exec zsh
      }

      if [[ "$TERM_PROGRAM" != "vscode" ]]; then
        DISABLE_AUTO_UPDATE="true"
        DISABLE_UPDATE_PROMPT="true"
      fi

      # ═══════════════════════════════════════════════════════════════════
      # ZSH Options - Organized by Category
      # Reference: https://zsh.sourceforge.io/Doc/Release/Options.html
      # ═══════════════════════════════════════════════════════════════════

      # Directory Navigation
      # --------------------
      setopt autocd            # Type dir name to cd (handled by programs.zsh.autocd)
      setopt autopushd         # cd pushes old dir onto stack
      setopt cdablevars        # cd to value of variable if not a directory
      setopt pushdminus        # Swap +/- meanings in pushd
      setopt pushdsilent       # Don't print stack after pushd/popd
      setopt pushdtohome       # pushd with no args goes to ~

      # History
      # -------
      setopt histignoredups    # Don't record duplicate entries
      setopt hist_allow_clobber # Add | to redirections in history for safety
      setopt no_share_history  # Don't share history between sessions (atuin handles sync)

      # Completion
      # ----------
      setopt always_to_end     # Move cursor to end after completion
      setopt recexact          # Accept exact match even if ambiguous
      setopt menucomplete      # First tab completes to first match, subsequent tabs cycle

      # Menu selection: show list and highlight current selection
      zstyle ':completion:*' menu select

      # Prioritize local directories in cd/z completion over cdpath and zoxide
      zstyle ':completion:*:(cd|z):*' tag-order 'local-directories' 'directory-stack' 'named-directories' 'path-directories'

      # Spelling Correction
      # -------------------
      setopt correct           # Correct spelling of commands
      setopt correctall        # Correct spelling of all arguments

      # Globbing
      # --------
      setopt extendedglob      # Extended glob operators (#, ~, ^)
      unsetopt globdots        # Don't match dotfiles without explicit dot

      # Job Control
      # -----------
      setopt autoresume        # Single-word commands resume existing job if matches
      setopt longlistjobs      # List jobs in long format
      setopt notify            # Report job status immediately, not at next prompt
      unsetopt bgnice          # Don't run background jobs at lower priority

      # Miscellaneous
      # -------------
      setopt mailwarning       # Warn if mail file has been accessed
      setopt rcquotes          # Two single-quotes inside quoted string = literal quote
      setopt sunkeyboardhack   # Ignore trailing | (for Sun keyboard quirks, legacy)

    '';
  };

  programs.home-manager.enable = true;
  programs.eza.enable = true;

  #  programs.neovim.enable = true;
  programs.nix-index.enable = true;
  programs.zoxide = {
    enable = true;
    enableZshIntegration = false; # Using zsh-defer for deferred init in initContent
  };

  programs.ssh = {
    enable = true;
    extraConfig = let
      # Generate host list from nixosHosts for RemoteForward configuration
      remoteForwardHosts = lib.concatStringsSep " " nixosHosts;
    in ''
      Host nas-01 nix-02 nix-03
        IdentityFile ~/.ssh/nix-builder-id_ed25519
        IdentitiesOnly no

      # Remote browser opening - forward port 7890 from remote Linux hosts
      # to localhost:7890 where browser-opener listens (macOS only)
      # Remote clipboard - forward port 7891 for clipboard-receiver
      # Remote notifications - forward port 7892 for notification-receiver
      Host ${remoteForwardHosts}
        RemoteForward 7890 localhost:7890
        RemoteForward 7891 localhost:7891
        RemoteForward 7892 localhost:7892

      Host *
        StrictHostKeyChecking no
        ForwardAgent yes


      Host github.com
        Hostname ssh.github.com
        Port 443
    '';
  };

  home.packages = with pkgs;
    [
      (pkgs.python312.withPackages (ppkgs: [
        ppkgs.libtmux
      ]))
      # unstablePkgs.aider-chat
      _1password-cli
      bottom
      claude-code
      devenv
      docker-compose
      forgejo-cli
      fx
      google-cloud-sdk
      kubernetes-helm
      kubectx
      kubectl
      opentofu

      inputs.opencode.packages.${pkgs.system}.default
      inputs.beads.packages.${pkgs.system}.default
      crushPackage

      procs
      unstablePkgs.sesh
      unstablePkgs.uv
      tldr
      unstablePkgs.zed-editor
      zsh-defer # Step 4: Needed for deferred initialization

      # Migrated from Homebrew brews
      # Kubernetes/Cloud tools
      kustomize
      minikube
      tanka
      jsonnet
      jsonnet-bundler

      # Development tools
      azure-cli
      golangci-lint
      shellcheck
      terraform
      trufflehog
      # zizmor  # not in nixpkgs yet

      # CLI utilities
      colordiff
      etcd
      fswatch
      git-absorb
      yazi
      glances
      hwatch
      # jd  # not in nixpkgs - keep in Homebrew
      jnv
      silver-searcher # the_silver_searcher (ag)
      inetutils # provides telnet

      # Monitoring
      prometheus
      prometheus-node-exporter

      # tmux (cross-platform)
      tmux

      # Fonts
      nerd-fonts.jetbrains-mono
    ]
    ++ lib.optionals stdenv.isDarwin [
      # macOS-only: tmux clipboard integration
      reattach-to-user-namespace
    ]
    ++ [
      # Additional tools
      tailscale
      lastpass-cli
    ];
}
