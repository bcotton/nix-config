{
  pkgs,
  unstablePkgs,
  lib,
  inputs,
  ...
}: let
  inherit (inputs) nixpkgs nixpkgs-unstable;
in {
  time.timeZone = "America/Denver";

  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      warn-dirty = false;
    };
    # Automate garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    alsa-utils
    intel-gpu-tools
    libva-utils
    file
    intel-media-driver
    jellyfin-ffmpeg
    hddtemp
    nil
    synergy
    television
    qemu
    quickemu
  ];

  ## pins to stable as unstable updates very often
  # nix.registry.nixpkgs.flake = inputs.nixpkgs;
  # nix.registry = {
  #   n.to = {
  #     type = "path";
  #     path = inputs.nixpkgs;
  #   };
  #   u.to = {
  #     type = "path";
  #     path = inputs.nixpkgs-unstable;
  #   };
  # };
}
