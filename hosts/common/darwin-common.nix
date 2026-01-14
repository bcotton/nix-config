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

    # Disable nix-darwin's Nix management when using Determinate Nix
    # Remove this if using standard Nix
    nix.enable = false;

    # These settings require nix.enable = true (standard Nix, not Determinate)
    # nix.settings = {
    #   experimental-features = ["nix-command" "flakes"];
    #   warn-dirty = false;
    # };
    # nix.registry.nixpkgs.flake = inputs.nixpkgs;
    # nix.registry = {
    #   n.to = { type = "path"; path = inputs.nixpkgs; };
    #   u.to = { type = "path"; path = inputs.nixpkgs-unstable; };
    # };
  };
}
