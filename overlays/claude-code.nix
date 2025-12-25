{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: final: prev: {
  # Override claude-code to pin to a specific version or upgrade to latest
  # To update to a new version:
  # 1. Update the version number below
  # 2. Run: nix-prefetch-url --unpack https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-VERSION.tgz
  # 3. Update the hash with the output
  # 4. Update npmDepsHash by setting it to lib.fakeHash, building, then using the correct hash from error
  claude-code = prev.claude-code.overrideAttrs (oldAttrs: rec {
    version = "2.0.76"; # Update this to the desired version

    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-46IqiGJZrZM4vVcanZj/vY4uxFH3/4LxNA+Qb6iIHDk=";
    };

    npmDepsHash = "sha256-mDErPWWqOe+3fKriTBLNCzXP48pmmlOMoB+kCP4FoT8=";
  });
}
