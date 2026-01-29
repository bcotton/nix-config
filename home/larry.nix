{
  config,
  pkgs,
  lib,
  unstablePkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.nix-moltbot.homeManagerModules.moltbot
  ];

  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  # Ensure systemd user services have coreutils in PATH
  systemd.user.sessionVariables = {
    PATH = "/run/current-system/sw/bin:/bin";
  };

  # Remove nix-managed config symlink - user manages their own moltbot.json
  home.activation.moltbotUserConfig = lib.hm.dag.entryAfter ["moltbotConfigFiles"] ''
    configFile="$HOME/.moltbot/moltbot.json"
    # Remove symlink if module created one, preserve user's real file
    if [ -L "$configFile" ]; then
      rm "$configFile"
      echo "Removed nix-managed moltbot.json symlink - manage config manually"
    fi
  '';

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    initContent = ''
      # Ensure systemd user session env vars are set
      export XDG_RUNTIME_DIR="/run/user/$(id -u)"
      export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    '';
  };

  programs.git = {
    enable = true;
  };

  # Moltbot gateway configuration
  programs.moltbot = {
    enable = true;

    # Disable first-party plugins for now
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

    instances.default = {
      enable = true;
      gatewayPort = 18789;

      # Providers
      providers.telegram = {
        enable = true;
        botTokenFile = "/run/agenix/moltbot-telegram-token";
        # TODO: Add telegram user IDs to allowFrom
        allowFrom = [
          7780937205
        ];
        groups = {
          "*" = {requireMention = true;};
        };
      };

      providers.anthropic.apiKeyFile = "/run/agenix/anthropic-api-key";

      # Additional config not covered by module options
      configOverrides = {
        agents.defaults.workspace = "/home/larry/moltbot";
        # New schema: gateway.auth.tokenFile is no longer valid
        # gateway.auth.mode = "token" with token read at runtime
        messages.tts = {
          provider = "openai";
          openai = {
            model = "gpt-4o-mini-tts";
            voice = "onyx";
          };
        };
      };
    };
  };
}
