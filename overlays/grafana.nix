{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: final: prev: let
  newVersion = "12.3.2";
  newSrc = prev.fetchFromGitHub {
    owner = "grafana";
    repo = "grafana";
    rev = "v${newVersion}";
    hash = "sha256-yyToc7jVLqCwZINhya35KGuCRP24TzWouHUm8Yd8e1o=";
  };
in {
  grafana = prev.grafana.override (oldArgs: {
    buildGoModule = args:
      oldArgs.buildGoModule (args
        // {
          version = newVersion;
          src = newSrc;

          vendorHash = "sha256-PN5YM0qstHm68ZvBsHBcRVD9NfrJ48EvBJlbwfsyBVY=";

          ldflags = [
            "-s"
            "-w"
            "-X main.version=${newVersion}"
          ];

          nativeBuildInputs = args.nativeBuildInputs ++ [prev.nodejs];

          missingHashes = ./grafana-missing-hashes.json;
          offlineCache = prev.yarn-berry_4.fetchYarnBerryDeps {
            src = newSrc;
            missingHashes = ./grafana-missing-hashes.json;
            hash = "sha256-RnYxki15s2crHHBDjpw7vLIMt5fIzM9rWTNjwQlLJ/o=";
          };

          postPatch = ''
            find . -name go.mod -not -path "./.bingo/*" -and -not -path "./devenv/*" -and -not -path "./hack/*" -and -not -path "./scripts/*" -and -not -path "./.citools/*" -print0 | while IFS= read -r -d "" line; do
              substituteInPlace "$line" \
                --replace-fail "go 1.25.6" "go 1.25.0"
            done
            find . -name go.mod -path "./.citools/*" -print0 | while IFS= read -r -d "" line; do
              substituteInPlace "$line" \
                --replace-fail "go 1.25.6" "go 1.25.0"
            done
            find . -name go.work -print0 | while IFS= read -r -d "" line; do
              substituteInPlace "$line" \
                --replace-fail "go 1.25.6" "go 1.25.0"
            done
            substituteInPlace Makefile \
              --replace-fail "GO_VERSION = 1.25.6" "GO_VERSION = 1.25.0"
          '';
        });
  });
}
