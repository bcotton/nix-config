{inputs, ...}: {
  # Export overlays as flake outputs so they can be used by other flakes
  # Note: These overlays are applied conditionally in hosts via overlays.nix module
  flake.overlays = {
    # Individual overlays for external consumption
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

    llm = final: prev: let
      pkgs = prev;
      lib = prev.lib;
    in
      (import ../overlays/llm.nix {
        config = {};
        inherit pkgs lib;
        unstablePkgs = prev;
      })
      final
      prev;

    # Default overlay for convenience - applies core overlays
    default = final: prev: let
      pkgs = prev;
      lib = prev.lib;
      claude-code-overlay =
        (import ../overlays/claude-code.nix {
          config = {};
          inherit pkgs lib;
          unstablePkgs = prev;
        })
        final
        prev;
      llm-overlay =
        (import ../overlays/llm.nix {
          config = {};
          inherit pkgs lib;
          unstablePkgs = prev;
        })
        final
        prev;
    in
      lib.foldl' lib.recursiveUpdate {} [
        claude-code-overlay
        llm-overlay
      ];
  };
}
