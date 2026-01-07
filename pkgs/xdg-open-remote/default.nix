{
  lib,
  stdenv,
  makeWrapper,
  coreutils,
  bash,
}:
stdenv.mkDerivation {
  pname = "xdg-open-remote";
  version = "1.0.1";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cp xdg-open-remote.sh $out/bin/xdg-open-remote
    chmod +x $out/bin/xdg-open-remote

    # Wrap to ensure timeout and bash are available
    # Uses bash's /dev/tcp for networking (no netcat needed)
    wrapProgram $out/bin/xdg-open-remote \
      --prefix PATH : ${lib.makeBinPath [coreutils bash]}
  '';

  meta = with lib; {
    description = "Open URLs in remote browser via SSH tunnel";
    longDescription = ''
      A utility that sends URLs through an SSH tunnel to open them in
      the browser on a remote desktop (typically a Mac). Falls back to
      local xdg-open if the tunnel is not available.
    '';
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [];
  };
}
