{inputs, ...}: {
  # Export overlays as flake outputs so they can be used by other flakes
  # Note: These overlays are applied conditionally in hosts via overlays.nix module
  flake.overlays = {
    # Individual overlays for external consumption
    # Each can be imported with: inputs.your-flake.overlays.yq
    yq = final: prev: let
      # Simplified version without config/unstablePkgs dependencies
      pkgs = prev;
      lib = prev.lib;
    in
      (import ../overlays/yq.nix {
        config = {};
        inherit pkgs lib;
        unstablePkgs = prev;
      })
      final
      prev;

    claude-code = final: prev: let
      pkgs = prev;
      lib = prev.lib;
    in
      (import ../overlays/claude-code.nix {
        config = {};
        inherit pkgs lib;
        unstablePkgs = prev;
      })
      final
      prev;

    # Default overlay for convenience - applies core overlays
    default = final: prev:
      prev.lib.foldl' prev.lib.recursiveUpdate {} [
        (
          (import ../overlays/yq.nix {
            config = {};
            pkgs = prev;
            lib = prev.lib;
            unstablePkgs = prev;
          })
          final
          prev
        )
        (
          (import ../overlays/claude-code.nix {
            config = {};
            pkgs = prev;
            lib = prev.lib;
            unstablePkgs = prev;
          })
          final
          prev
        )
      ];
  };
}
