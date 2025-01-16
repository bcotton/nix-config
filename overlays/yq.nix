{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: self: super: {
  yq = pkgs.buildGoModule rec {
    pname = "yq-go";
    version = "4.45.1";

    src = pkgs.fetchFromGitHub {
      owner = "mikefarah";
      repo = "yq";
      rev = "v${version}";
      hash = "sha256-AsTDbeRMb6QJE89Z0NGooyTY3xZpWFoWkT7dofsu0DI=";
    };

    vendorHash = "sha256-d4dwhZYzEuyh1zJQ2xU0WkygHjoVLoCBrDKuAHUzu1w=";

    nativeBuildInputs = [pkgs.installShellFiles];

    postInstall = ''
      installShellCompletion --cmd yq \
        --bash <($out/bin/yq shell-completion bash) \
        --fish <($out/bin/yq shell-completion fish) \
        --zsh <($out/bin/yq shell-completion zsh)
    '';

    meta = with lib; {
      description = "Portable command-line YAML processor";
      homepage = "https://mikefarah.gitbook.io/yq/";
      changelog = "https://github.com/mikefarah/yq/raw/v${version}/release_notes.txt";
      mainProgram = "yq";
      license = [licenses.mit];
    };
  };
}
