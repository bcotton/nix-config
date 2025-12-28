{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.nix-builder.client;
in {
  options.services.nix-builder.client = {
    enable = mkEnableOption "Nix cache client";

    cacheUrl = mkOption {
      type = types.str;
      default = "http://nas-01:5000"; # Default Tailscale hostname
      description = "Binary cache URL (via Tailscale or direct)";
    };

    publicKey = mkOption {
      type = types.str;
      description = "Binary cache public signing key";
    };

    priority = mkOption {
      type = types.int;
      default = 30;
      description = "Cache priority (lower = higher priority, default upstream is 40)";
    };
  };

  config = mkIf cfg.enable {
    nix.settings = {
      # Add our cache as a substituter (highest priority by being first)
      substituters = [
        cfg.cacheUrl
        # Keep upstream caches
        "https://cache.nixos.org"
      ];

      # Trust the cache signing key
      trusted-public-keys = [
        cfg.publicKey
        # Keep upstream keys
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };
  };
}
