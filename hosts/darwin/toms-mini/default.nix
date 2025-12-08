# This is imported as module, from the top-level flake
{
  config,
  pkgs,
  unstablePkgs,
  lib,
  inputs,
  hostName,
  ...
}: let
  # Get merged variables (defaults + host overrides)
  commonLib = import ../../common/lib.nix;
  variables = commonLib.getHostVariables hostName;
in {
  imports = [../toms-darwin/default.nix];

  services.clubcotton.toms-darwin = {
    enable = true;
    useP11KitOverlay = false;
  };
}
