{
  config,
  pkgs,
  lib,
  unstablePkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.nix-openclaw.homeManagerModules.openclaw
  ];

  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  # Ensure systemd user services have coreutils in PATH
  systemd.user.sessionVariables = {
    PATH = "/run/current-system/sw/bin:/bin";
  };

  # Handle existing config - remove old nix symlinks before home-manager runs
  # This must run BEFORE checkLinkTargets to avoid file conflict errors
  home.activation.openClawPreCleanup = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    configFile="$HOME/.openclaw/openclaw.json"
    # Also check old moltbot path for migration
    oldConfigFile="$HOME/.moltbot/moltbot.json"
    for f in "$configFile" "$oldConfigFile"; do
      if [ -L "$f" ]; then
        rm "$f"
        echo "Removed existing nix-managed symlink: $f"
      fi
    done
  '';

  # After openclaw creates its config, convert symlink to regular file for runtime writes
  home.activation.openclawUserConfig = lib.hm.dag.entryAfter ["openclawConfigFiles"] ''
    configFile="$HOME/.openclaw/openclaw.json"
    if [ -L "$configFile" ]; then
      content=$(cat "$configFile")
      rm "$configFile"
      echo "$content" > "$configFile"
      chmod 644 "$configFile"
      echo "Converted nix symlink to regular file for runtime management"
    fi
  '';

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

      # Forgejo
      tea = "tea --login forgejo";

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
        success_symbol = "[🎭](bold green)";
        error_symbol = "[🎭](bold red)";
      };
      directory = {
        truncation_length = 3;
        fish_style_pwd_dir_length = 1;
      };
      git_branch = {
        symbol = " ";
      };
      git_status = {
        conflicted = "⚔️ ";
        ahead = "⬆️ ";
        behind = "⬇️ ";
        diverged = "↕️ ";
        modified = "📝";
        staged = "✅";
        untracked = "❓";
      };
      nix_shell = {
        symbol = "❄️ ";
      };
    };
  };

  # ─────────────────────────────────────────────────────────────
  # Git configuration
  # ─────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    userName = "Larry";
    userEmail = "larry@nix-02";

    extraConfig = {
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

    # Delta for beautiful diffs
    delta = {
      enable = true;
      options = {
        navigate = true;
        light = false;
        side-by-side = true;
        line-numbers = true;
      };
    };
  };

  # Openclaw gateway configuration
  programs.openclaw = {
    enable = true;

    # Disable first-party plugins
    firstParty = {
      summarize.enable = false;
      peekaboo.enable = false;
      oracle.enable = false;
      poltergeist.enable = false;
      sag.enable = false;
      camsnap.enable = false;
      gogcli.enable = false;
      bird.enable = false;
      sonoscli.enable = false;
      imsg.enable = false;
    };

    # Schema-typed config (replaces providers.* and configOverrides)
    config = {
      channels.telegram = {
        tokenFile = "/run/agenix/moltbot-telegram-token";
        allowFrom = [
          7780937205
        ];
        groups = {
          "*" = {requireMention = true;};
        };
      };
      agents.defaults.workspace = "/home/larry/moltbot";
      messages.tts = {
        provider = "openai";
        openai = {
          model = "gpt-4o-mini-tts";
          voice = "onyx";
        };
      };
    };

    # Instance config
    instances.default = {
      enable = true;
      gatewayPort = 18789;
      systemd.enable = true;
    };
  };

  # Extend openclaw-gateway systemd service
  systemd.user.services.openclaw-gateway = {
    Unit = {
      After = ["network-online.target"];
      Wants = ["network-online.target"];
    };
    Service = {
      # Inject Anthropic API key from agenix secret
      # %t is systemd specifier for runtime directory (/run/user/$UID)
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'echo ANTHROPIC_API_KEY=$(cat /run/agenix/anthropic-api-key) > %t/openclaw-env'";
      EnvironmentFile = "%t/openclaw-env";
      # PATH for daemon with required directories
      Environment = [
        "PATH=/home/larry/.local/bin:/home/larry/.npm-global/bin:/home/larry/bin:/home/larry/.nvm/current/bin:/home/larry/.fnm/current/bin:/home/larry/.volta/bin:/home/larry/.asdf/shims:/home/larry/.local/share/pnpm:/home/larry/.bun/bin:/usr/local/bin:/usr/bin:/run/current-system/sw/bin:/bin"
      ];
      RestartSec = lib.mkForce "5s";
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
      set -g status-left '#[fg=#89b4fa]🎭 #S '
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

    # Nix tools
    nil # nix LSP
    alejandra # nix formatter

    # Fun
    cowsay
    lolcat
  ];
}
