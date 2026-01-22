# This is imported as module, from the top-level flake
{
  config,
  pkgs,
  unstablePkgs,
  lib,
  inputs,
  hostName,
  ...
}: let
  # Get merged variables (defaults + host overrides)
  commonLib = import ../../common/lib.nix;
  variables = commonLib.getHostVariables hostName;
in {
  imports = [../toms-darwin/default.nix];

  services.clubcotton.toms-darwin = {
    enable = true;
    useP11KitOverlay = true;
  };

  nixpkgs.overlays = [
    (final: prev: {
      # Target the specific package that is failing the build.
      # In your log, this was 'rustfmt'.
      rustfmt = prev.rustfmt.overrideAttrs (oldAttrs: {
        # This environment variable passes flags directly to the linker.
        # It's the standard way to handle this issue in nixpkgs.
        NIX_LDFLAGS = "-headerpad_max_install_names";
      });

      # You could apply this to other packages if they show the same error.
      # another-failing-package = prev.another-failing-package.overrideAttrs ...
    })
  ];

  # stdenv.mkDerivation.NIX_LDFLAGS = "-headerpad_max_install_names";

  homebrew = {
    enable = true;
    # updates homebrew packages on activation,
    # can make darwin-rebuild much slower (otherwise i'd forget to do it ever though)
    onActivation.upgrade = true;

    taps = [
      #
    ];
    brews = [];
    casks = ["reaper"];
    masApps = {};
  };
}
