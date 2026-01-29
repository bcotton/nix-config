{
  config,
  pkgs,
  lib,
  unstablePkgs,
  localPackages,
  inputs,
  ...
}: {
  config.nixpkgs.overlays = [
    # Fix bird alias that was removed in nixpkgs - point to bird2
    (final: prev: {
      bird = prev.bird2;
    })

    # nix-moltbot overlay - provides pkgs.moltbot
    inputs.nix-moltbot.overlays.default

    # Create a single overlay function that composes all conditional overlays
    (final: prev:
      lib.foldl' lib.recursiveUpdate {} [
        # Core tools that should always be available
        ((import ./overlays/qmk.nix {inherit config pkgs lib unstablePkgs;}) final prev)
        ((import ./overlays/claude-code.nix {inherit config pkgs lib unstablePkgs;}) final prev)
        ((import ./overlays/llm.nix {inherit config pkgs lib unstablePkgs;}) final prev)
        # tmux-fingers with stdin close fix (PR pending upstream)
        ((import ./overlays/tmux-fingers.nix {inherit config pkgs lib unstablePkgs;}) final prev)

        # Beets is only available on Linux due to gst-python build issues on Darwin
        (lib.optionalAttrs prev.stdenv.isLinux
          ((import ./overlays/beets.nix {inherit config pkgs lib unstablePkgs;}) final prev))

        # Conditional overlays based on service/module usage
        (lib.optionalAttrs (config.services.jellyfin.enable or false)
          ((import ./overlays/jellyfin.nix {inherit config pkgs lib unstablePkgs;}) final prev))

        (lib.optionalAttrs (config.boot.supportedFilesystems.zfs or false)
          ((import ./overlays/smart-disk-monitoring.nix {inherit config pkgs lib unstablePkgs;}) final prev))

        (lib.optionalAttrs ((config.programs.git.enable or false) && (config.programs.git.delta.enable or false))
          ((import ./overlays/delta.nix {inherit config pkgs lib unstablePkgs;}) final prev))
      ])
  ];
}
