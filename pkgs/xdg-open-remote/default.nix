{
  lib,
  stdenv,
  makeWrapper,
  netcat-gnu,
}:
stdenv.mkDerivation {
  pname = "xdg-open-remote";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cp xdg-open-remote.sh $out/bin/xdg-open-remote
    chmod +x $out/bin/xdg-open-remote

    # Wrap to include netcat in PATH
    wrapProgram $out/bin/xdg-open-remote \
      --prefix PATH : ${lib.makeBinPath [netcat-gnu]}
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
