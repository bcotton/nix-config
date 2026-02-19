{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: self: super: let
  # Create a custom beets with all plugins via python3.pkgs.beets
  customPythonBeets =
    (super.python3.pkgs.beets.override {
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
    })
    .overridePythonAttrs {
      src = pkgs.fetchFromGitHub {
        owner = "bcotton";
        repo = "beets";
        rev = "aa265b4fc8716666aef82f035787ecc22a4e0403";
        hash = "sha256-eUtAtYxkhEViifyKZT4t0T16hp8zatdvcKPsMSDCqaA=";
      };
      # Custom fork may not produce the _sphinx_design_static dir
      preInstallSphinx = ''
        rm -rf .sphinx/man/man/_sphinx_design_static
      '';
      # Custom fork has different plugin list than upstream; skip plugin list check
      doCheck = false;
    };
in {
  # Override beets at the top level to use the custom version
  beets = super.python3.pkgs.toPythonApplication customPythonBeets;
}
