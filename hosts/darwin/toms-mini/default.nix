# This is imported as module, from the top-level flake
{
  config,
  pkgs,
  unstablePkgs,
  lib,
  inputs,
  ...
}: {
  imports = [../toms-darwin/default.nix];

  services.clubcotton.toms-darwin = {
    enable = true;
    useP11KitOverlay = false;
  };
}
