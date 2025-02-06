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
    services.nix-daemon.enable = true;

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

    launchd.user.agents = lib.mkIf (pkgs.stdenv.isDarwin && builtins.any (user: config.home-manager.users.${user}.programs.atuin-config.enable-daemon) (builtins.attrNames config.home-manager.users)) {
      atuin-daemon = {
        serviceConfig = {
          ProgramArguments = ["${pkgs.atuin}/bin/atuin" "daemon"];
          KeepAlive = true;
          RunAtLoad = true;
          StandardOutPath = "/tmp/atuin-daemon.log";
          StandardErrorPath = "/tmp/atuin-daemon.error.log";
        };
      };
    };
  };
}
