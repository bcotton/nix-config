{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: self: super: {
  ctlptl = super.ctlptl.overrideAttrs (oldAttrs: rec {
    version = "0.8.42";
    src = pkgs.fetchFromGitHub {
      owner = "tilt-dev";
      repo = "ctlptl";
      rev = "v${version}";
      hash = "sha256-yx1Fjsad7mjFmv/BFGZwH9xbidGXLT0FKI/cgMi2bU8=";
    };
    vendorHash = "sha256-d9TijRzBpMvRrOMexGtewtAA9XpLwDTjPnPzt7G67Cs=";
    ldflags = [
      "-s"
      "-w"
      "-X main.version=${version}"
    ];
  });
}
