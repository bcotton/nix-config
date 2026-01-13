{
  config,
  pkgs,
  unstablePkgs,
  inputs,
  lib,
  localPackages,
  ...
}: {
  config = {
    system.stateVersion = 5;

    nix = {
      #package = lib.mkDefault pkgs.unstable.nix;
      settings = {
        experimental-features = ["nix-command" "flakes"];
        warn-dirty = false;
      };
    };

    # pins to stable as unstable updates very often
    nix.registry.nixpkgs.flake = inputs.nixpkgs;
    nix.registry = {
      n.to = {
        type = "path";
        path = inputs.nixpkgs;
      };
      u.to = {
        type = "path";
        path = inputs.nixpkgs-unstable;
      };
    };

    # This can't be in home manager, so put in in the darwin config
    # it checks against the home-manager users to see if the daemon should be enabled
    # taken from: https://www.danielcorin.com/til/nix-darwin/launch-agents/
    # you might need to 'launchctl unload/load' to start atuin if it will not start automatically
    launchd.user.agents = lib.mkMerge [
      # Atuin daemon
      (lib.mkIf (pkgs.stdenv.isDarwin && builtins.any (user: config.home-manager.users.${user}.programs.atuin-config.enable-daemon) (builtins.attrNames config.home-manager.users)) {
        atuin-daemon = {
          serviceConfig = {
            ProgramArguments = ["${pkgs.atuin}/bin/atuin" "daemon"];
            KeepAlive = true;
            RunAtLoad = true;
            ThrottleInterval = 10;
            StandardOutPath = "/tmp/atuin-daemon.log";
            StandardErrorPath = "/tmp/atuin-daemon.error.log";
          };
        };
      })

      # Browser opener daemon - listens for URLs from remote hosts via SSH tunnel
      (lib.mkIf (pkgs.stdenv.isDarwin && builtins.any (user: config.home-manager.users.${user}.programs.browser-opener.enable or false) (builtins.attrNames config.home-manager.users)) {
        browser-opener = {
          serviceConfig = {
            ProgramArguments = ["${localPackages.browser-opener}/bin/browser-opener"];
            KeepAlive = true;
            RunAtLoad = true;
            ThrottleInterval = 10;
            StandardOutPath = "/tmp/browser-opener.log";
            StandardErrorPath = "/tmp/browser-opener.error.log";
          };
        };
      })

      # Clipboard receiver daemon - listens for text from remote hosts via SSH tunnel
      (lib.mkIf (pkgs.stdenv.isDarwin && builtins.any (user: config.home-manager.users.${user}.programs.clipboard-receiver.enable or false) (builtins.attrNames config.home-manager.users)) {
        clipboard-receiver = {
          serviceConfig = {
            ProgramArguments = ["${localPackages.clipboard-receiver}/bin/clipboard-receiver"];
            KeepAlive = true;
            RunAtLoad = true;
            ThrottleInterval = 10;
            StandardOutPath = "/tmp/clipboard-receiver.log";
            StandardErrorPath = "/tmp/clipboard-receiver.error.log";
          };
        };
      })

      # Notification receiver daemon - listens for notifications from remote hosts via SSH tunnel
      (lib.mkIf (pkgs.stdenv.isDarwin && builtins.any (user: config.home-manager.users.${user}.programs.notification-receiver.enable or false) (builtins.attrNames config.home-manager.users)) {
        notification-receiver = {
          serviceConfig = {
            ProgramArguments = ["${localPackages.notification-receiver}/bin/notification-receiver"];
            KeepAlive = true;
            RunAtLoad = true;
            ThrottleInterval = 10;
            StandardOutPath = "/tmp/notification-receiver.log";
            StandardErrorPath = "/tmp/notification-receiver.error.log";
          };
        };
      })

      # Arc Tab Archiver - captures auto-archived Arc browser tabs to Obsidian
      (lib.mkIf (pkgs.stdenv.isDarwin && builtins.any (user: config.home-manager.users.${user}.programs.arc-tab-archiver.enable or false) (builtins.attrNames config.home-manager.users)) (
        let
          # Get the first user with arc-tab-archiver enabled
          enabledUsers = builtins.filter (user: config.home-manager.users.${user}.programs.arc-tab-archiver.enable or false) (builtins.attrNames config.home-manager.users);
          firstUser = builtins.head enabledUsers;
          userCfg = config.home-manager.users.${firstUser}.programs.arc-tab-archiver;
        in {
          arc-tab-archiver = {
            serviceConfig = {
              ProgramArguments = ["${localPackages.arc-tab-archiver}/bin/arc-tab-archiver"];
              StartInterval = userCfg.interval;
              RunAtLoad = true;
              EnvironmentVariables = {
                OBSIDIAN_DIR = userCfg.obsidianDir;
              };
              StandardOutPath = "/tmp/arc-tab-archiver.log";
              StandardErrorPath = "/tmp/arc-tab-archiver.log";
            };
          };
        }
      ))
    ];
  };
}
