{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  installShellFiles,
}:
rustPlatform.buildRustPackage rec {
  pname = "workmux";
  version = "0.1.58";

  src = fetchFromGitHub {
    owner = "raine";
    repo = "workmux";
    rev = "v${version}";
    sha256 = "sha256-js6wpmLQl7TbtcSjEMK0qOa+44cDe87zLr4b8ryDh0A=";
  };

  cargoHash = "sha256-rUKkSziRux3qjAiaEUXJEztuApvO/YPbn7ycnm043Mc=";

  nativeBuildInputs = [
    pkg-config
    installShellFiles
  ];

  postInstall = ''
    # Set HOME to avoid log directory creation errors during completion generation
    export HOME=$TMPDIR
    installShellCompletion --cmd workmux \
      --bash <($out/bin/workmux completions bash) \
      --fish <($out/bin/workmux completions fish) \
      --zsh <($out/bin/workmux completions zsh)
  '';

  meta = with lib; {
    description = "Parallel development in tmux with git worktrees";
    longDescription = ''
      Workmux combines git worktrees with tmux window management to streamline
      parallel development. It creates isolated workspaces where each branch
      gets its own directory and tmux window, eliminating friction when juggling
      multiple features simultaneously.
    '';
    homepage = "https://github.com/raine/workmux";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = [];
  };
}
