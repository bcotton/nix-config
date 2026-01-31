{
  pkgs,
  unstablePkgs,
  lib,
  inputs,
  ...
}: let
  inherit (inputs) nixpkgs nixpkgs-unstable;
in {
  # timeZone is set via variables.nix (default: America/Denver)

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

  # Workaround for scripts expecting FHS paths (e.g., nix-openclaw uses coreutils)
  system.activationScripts.binCompat = ''
    mkdir -p /bin
    for cmd in cat chmod chown cp ln ls mkdir mv rm; do
      ln -sf ${pkgs.coreutils}/bin/$cmd /bin/$cmd
    done
  '';

  environment.systemPackages = with pkgs; [
    inputs.isd.packages."${system}".default
    alsa-utils
    # intel-gpu-tools
    libva-utils
    file
    # intel-media-driveupr
    jellyfin-ffmpeg
    hddtemp
    nil
    nixos-shell
    nodejs_22
    pnpm_10
    synergy
    qemu
    quickemu
    inputs.ghostty.packages."${system}".default
    zstd
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
