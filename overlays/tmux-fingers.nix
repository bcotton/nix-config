# Override tmux-fingers to use bcotton's fork with stdin close fix
# PR: https://github.com/Morantron/tmux-fingers/pull/XXX
{
  config,
  pkgs,
  lib,
  unstablePkgs,
}: final: prev: let
  # Rebuild tmux-fingers from bcotton's fork with the fix
  fingersFixed = prev.crystal.buildCrystalPackage rec {
    format = "shards";
    version = "2.4.0-fix-stdin";
    pname = "fingers";
    src = prev.fetchFromGitHub {
      owner = "bcotton";
      repo = "tmux-fingers";
      rev = "642ee7f0fd35a71b6edf8a0c2f753fb8dd82819c";
      sha256 = "sha256-NOd0bjNFktpJeQUmmwPo/mN8kvfQ8zAPvk22Vcf1ey8=";
    };

    # Use the same shards.nix from nixpkgs (dependencies unchanged)
    shardsFile = "${prev.path}/pkgs/misc/tmux-plugins/tmux-fingers/shards.nix";
    crystalBinaries.tmux-fingers.src = "src/fingers.cr";

    postInstall = ''
      shopt -s dotglob extglob
      rm -rv !("tmux-fingers.tmux"|"bin")
      shopt -u dotglob extglob
    '';

    doCheck = false;
    doInstallCheck = false;
  };
in {
  tmuxPlugins =
    prev.tmuxPlugins
    // {
      fingers = prev.tmuxPlugins.mkTmuxPlugin {
        inherit (fingersFixed) version src meta;

        pluginName = fingersFixed.src.repo;
        rtpFilePath = "tmux-fingers.tmux";

        patches = [
          (prev.replaceVars "${prev.path}/pkgs/misc/tmux-plugins/tmux-fingers/fix.patch" {
            tmuxFingersDir = "${fingersFixed}/bin";
          })
        ];
      };
    };
}
