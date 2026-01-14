{
  pkgs,
  unstablePkgs,
  lib,
  inputs,
  system,
  ...
}: let
  inherit (inputs) nixpkgs nixpkgs-unstable;
  isX86 = system == "x86_64-linux";
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

  environment.systemPackages = with pkgs;
    [
      alsa-utils
      file
      hddtemp
      nil
      synergy
      television
      qemu
      quickemu
    ]
    ++ lib.optionals isX86 [
      intel-gpu-tools
      intel-media-driver
      libva-utils
      jellyfin-ffmpeg
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
