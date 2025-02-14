{
  config,
  pkgs,
  lib,
  unstablePkgs,
  localPackages,
  ...
}: {
  options.programs.television = {
    enable = lib.mkEnableOption "television fuzzy finder";
  };

  config.nixpkgs.overlays = [
    # Create a single overlay function that composes all conditional overlays
    (final: prev:
      lib.foldl' lib.recursiveUpdate {} [
        # Core tools that should always be available
        ((import ./overlays/yq.nix {inherit config pkgs lib unstablePkgs;}) final prev)
        ((import ./overlays/primp.nix {inherit config pkgs lib unstablePkgs;}) final prev)

        # Conditional overlays based on service/module usage
        (lib.optionalAttrs (config.services.jellyfin.enable or false)
          ((import ./overlays/jellyfin.nix {inherit config pkgs lib unstablePkgs;}) final prev))

        (lib.optionalAttrs (config.boot.supportedFilesystems.zfs or false)
          ((import ./overlays/smart-disk-monitoring.nix {inherit config pkgs lib unstablePkgs;}) final prev))

        (lib.optionalAttrs (config.services.k3s.enable or false)
          ((import ./overlays/ctlptl.nix {inherit config pkgs lib unstablePkgs;}) final prev))

        (lib.optionalAttrs (config.programs.television.enable or false)
          ((import ./overlays/television.nix {inherit config pkgs lib unstablePkgs;}) final prev))

        (lib.optionalAttrs ((config.programs.git.enable or false) && (config.programs.git.delta.enable or false))
          ((import ./overlays/delta.nix {inherit config pkgs lib unstablePkgs;}) final prev))
      ])
  ];
}
