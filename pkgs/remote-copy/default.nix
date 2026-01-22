{
  lib,
  stdenv,
  makeWrapper,
  coreutils,
  bash,
}:
stdenv.mkDerivation {
  pname = "remote-copy";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cp remote-copy.sh $out/bin/remote-copy
    chmod +x $out/bin/remote-copy

    # Wrap to ensure timeout and bash are available
    # Uses bash's /dev/tcp for networking (no netcat needed)
    wrapProgram $out/bin/remote-copy \
      --prefix PATH : ${lib.makeBinPath [coreutils bash]}
  '';

  meta = with lib; {
    description = "Copy text to remote clipboard via SSH tunnel";
    longDescription = ''
      A utility that sends text through an SSH tunnel to copy it to
      the clipboard on a remote desktop (typically a Mac). Falls back to
      tmux buffer if the tunnel is not available.
    '';
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [];
  };
}
