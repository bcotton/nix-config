{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "gwtmux";
  version = "unstable-2025-12-24";

  src = fetchFromGitHub {
    owner = "snapwich";
    repo = "gwtmux";
    rev = "76db6f6e31b77147e0f11ad7ce06e1e90507d8b2"; # Latest commit - fix some git error messaging
    sha256 = "sha256-8RLTqATi8/9XXZe0UrrrkfAt3oaHL4XmKCzEQkXA6no=";
  };

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/share/gwtmux
    cp gwtmux.sh $out/share/gwtmux/
    chmod +x $out/share/gwtmux/gwtmux.sh
  '';

  meta = with lib; {
    description = "A bash function for managing tmux and git worktrees";
    longDescription = ''
      Git worktree + tmux integration. Create and manage git worktrees
      in dedicated tmux windows. Supports creating worktrees from branches
      or PR numbers, cleanup operations, and renaming workflows.
    '';
    homepage = "https://github.com/snapwich/gwtmux";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = [];
  };
}
