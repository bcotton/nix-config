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
    bitwarden-desktop
    obsidian
    discord
    reaper
    zotero
    firefox
    vscode

    # Nixbook and Nixtop Packages
    kmonad
  ];
}
