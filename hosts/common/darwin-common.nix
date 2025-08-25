{
  config,
  pkgs,
  unstablePkgs,
  inputs,
  lib,
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
    launchd.user.agents = lib.mkIf (pkgs.stdenv.isDarwin && builtins.any (user: config.home-manager.users.${user}.programs.atuin-config.enable-daemon) (builtins.attrNames config.home-manager.users)) {
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
    };
  };
}
