{
  pkgs,
  unstablePkgs,
  lib,
  inputs,
  ...
}: let
  inherit (inputs) nixpkgs nixpkgs-unstable;
in {
  environment.systemPackages = with pkgs; [
    pipewire
    wireplumber
    yabridge
    wineWowPackages.stable
    winetricks
  ];
}
