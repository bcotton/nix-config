{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: {
  nixpkgs.overlays = [
    (final: prev:
      (import ./overlays/yq.nix {inherit config pkgs lib unstablePkgs;}) final prev)
  ];
}
