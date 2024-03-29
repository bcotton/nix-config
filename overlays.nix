{
  config,
  pkgs,
  lib,
  ...
}: let
  version = "2.0-1365";
  urlVersion = builtins.replaceStrings ["." "-"] ["00" "0"] version;
in {
  nixpkgs.overlays = [
    (self: super: {
      roon-server = super.roon-server.overrideAttrs {
        version = version;
        src = pkgs.fetchurl {
          url = "https://download.roonlabs.com/updates/production/RoonServer_linuxx64_${urlVersion}.tar.bz2";
          hash = "sha256-RwmBszv3zCFX8IvDu/XMVu92EH/yd1tyaw0P4CmODCA=";
        };
        #    src = newsrc;
      };
    })

    (self: super: {
      delta = super.delta.overrideAttrs (previousAttrs: {
        # src = pkgs.fetchFromGitHub {
        #   owner = "dandavison";
        #   repo = "delta";
        #   rev = "main";
        #   sha256 = "sha256-3sMkxmchgC4mvhjagiZLfvZHR5PwRwNYGCi0fyUCkiE=";
        # };
        # cargoHash = "";
        postInstall =
          (previousAttrs.postInstall or "")
          + ''
            cp $src/themes.gitconfig $out/share
          '';
      });
    })

    # (final: prev: {
    #   python3 = prev.python3.override {
    #     packageOverrides = python-final: python-prev: {
    #       twisted = python-prev.mopidy-mopify.overrideAttrs (oldAttrs: {
    #         src = prev.fetchPypi {
    #           pname = "Mopidy-Mopify";
    #           version = "1.7.3";
    #           sha256 = "93ad2b3d38b1450c8f2698bb908b0b077a96b3f64cdd6486519e518132e23a5c";
    #         };
    #       });
    #     };
    #   };
    # })
  ];
}
