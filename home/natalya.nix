{
  config,
  pkgs,
  lib,
  unstablePkgs,
  inputs,
  ...
}: {
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  # Ensure systemd user services have coreutils in PATH
  systemd.user.sessionVariables = {
    PATH = "/run/current-system/sw/bin:/bin";
  };

  # Add pnpm local bin to user's shell PATH
  home.sessionPath = [
    "/home/natalya/node_modules/.bin"
  ];

  # ─────────────────────────────────────────────────────────────
  # Shell: zsh with starship prompt
  # ─────────────────────────────────────────────────────────────
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;

    shellAliases = {
      # Modern replacements
      ls = "eza --icons";
      ll = "eza -la --icons --git";
      lt = "eza --tree --icons";
      cat = "bat";
      grep = "rg";
      find = "fd";

      # Git shortcuts
      gs = "git status";
      gd = "git diff";
      gdc = "git diff --cached";
      gl = "git log --oneline -20";
      gco = "git checkout";

      # Navigation
      ".." = "cd ..";
      "..." = "cd ../..";

      # Safety
      rm = "rm -i";
      mv = "mv -i";
      cp = "cp -i";
    };

    initContent = ''
      # Starship prompt
      eval "$(starship init zsh)"

      # Better history
      setopt HIST_IGNORE_DUPS
      setopt HIST_IGNORE_SPACE
      setopt SHARE_HISTORY

      # Ensure systemd user session env vars are set
      export XDG_RUNTIME_DIR="/run/user/$(id -u)"
      export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"

      # tea completion if available (source the file directly to avoid "Fetching" output)
      [[ -f ~/.config/tea/autocomplete.zsh ]] && PROG=tea _CLI_ZSH_AUTOCOMPLETE_HACK=1 source ~/.config/tea/autocomplete.zsh
    '';
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      character = {
        success_symbol = "[sparkle](bold green)";
        error_symbol = "[sparkle](bold red)";
      };
      directory = {
        truncation_length = 3;
        fish_style_pwd_dir_length = 1;
      };
      git_branch = {
        symbol = " ";
      };
      git_status = {
        conflicted = "! ";
        ahead = "^ ";
        behind = "v ";
        diverged = "~ ";
        modified = "* ";
        staged = "+ ";
        untracked = "? ";
      };
      nix_shell = {
        symbol = "nix ";
      };
    };
  };

  # ─────────────────────────────────────────────────────────────
  # Git configuration
  # ─────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Natalya";
        email = "natalya.verscheure@gmail.com";
      };
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;

      alias = {
        br = "branch";
        co = "checkout";
        ci = "commit";
        st = "status";
        lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%C(bold blue)<%an>%Creset' --abbrev-commit";
        lga = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%C(bold blue)<%an>%Creset' --abbrev-commit --all";
      };

      core.whitespace = "trailing-space,space-before-tab";
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";
    };
  };

  # Delta for beautiful diffs
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      light = false;
      side-by-side = true;
      line-numbers = true;
    };
  };

  # ─────────────────────────────────────────────────────────────
  # Other useful programs
  # ─────────────────────────────────────────────────────────────
  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    historyLimit = 10000;
    keyMode = "vi";
    prefix = "C-a";

    extraConfig = ''
      # Better splits
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # Easy reload
      bind r source-file ~/.tmux.conf \; display "Reloaded!"

      # Mouse support
      set -g mouse on

      # Status bar
      set -g status-style 'bg=#1e1e2e fg=#cdd6f4'
      set -g status-left '#[fg=#89b4fa]* #S '
      set -g status-right '#[fg=#a6adc8]%H:%M'
    '';
  };

  # ─────────────────────────────────────────────────────────────
  # Packages
  # ─────────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    # Modern CLI tools
    eza # better ls
    bat # better cat
    ripgrep # better grep
    fd # better find
    jq # JSON processor
    yq # YAML processor
    htop # process viewer
    bottom # fancy htop
    procs # better ps

    # Git tools
    delta # beautiful diffs
    git-absorb # automatic fixup commits

    # Forgejo/Git workflow
    tea # Gitea/Forgejo CLI

    # Development
    tldr # simplified man pages
    direnv # per-directory environments
    pnpm
    nodejs_22

    # Nix tools
    nil # nix LSP
    alejandra # nix formatter

    # Fun
    cowsay
    lolcat
  ];
}
