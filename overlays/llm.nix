{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: final: prev: {
  # Override llm to pin to version 0.28
  # To update to a new version:
  # 1. Update the version number below
  # 2. Run: nix-prefetch-url --unpack https://files.pythonhosted.org/packages/source/l/llm/llm-VERSION.tar.gz
  # 3. Update the hash with the output
  llm = prev.llm.overrideAttrs (oldAttrs: rec {
    version = "0.28";

    src = prev.fetchPypi {
      pname = "llm";
      inherit version;
      hash = "sha256-0dikahngpxs6gp2bhbp05asw96nz6g37nfg4yrl0q9ywr3l0mvwy";
    };
  });
}
