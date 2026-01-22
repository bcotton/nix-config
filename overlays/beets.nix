{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: self: super: let
  # Create a custom beets with all plugins
  customBeets = super.beetsPackages.beets-unstable.override {
    src = pkgs.fetchFromGitHub {
      owner = "bcotton";
      repo = "beets";
      rev = "aa265b4fc8716666aef82f035787ecc22a4e0403";
      hash = "sha256-eUtAtYxkhEViifyKZT4t0T16hp8zatdvcKPsMSDCqaA=";
    };
    extraPatches = [
      # Bash completion fix for Nix
      # ./patches/bash-completion-always-print.patch
    ];
    pluginOverrides = {
      beets_id3extract = {
        enable = true;
        propagatedBuildInputs = [(pkgs.python3.pkgs.callPackage ../pkgs/beets_id3extract {})];
      };
      _typing = {
        enable = true;
        builtin = true;
        testPaths = [];
      };
    };
    extraNativeBuildInputs = with pkgs.python3Packages; [
      requests-mock
    ];
  };
in {
  beetsPackages =
    super.beetsPackages
    // {
      beets-stable = customBeets;
    };

  # Expose beets-unstable at the top level to use the custom version
  beets-unstable = customBeets;
}
