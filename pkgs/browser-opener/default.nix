{
  lib,
  stdenv,
  makeWrapper,
  socat,
}:
stdenv.mkDerivation {
  pname = "browser-opener";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cp browser-opener.sh $out/bin/browser-opener
    chmod +x $out/bin/browser-opener

    # Wrap to include socat in PATH
    wrapProgram $out/bin/browser-opener \
      --prefix PATH : ${lib.makeBinPath [socat]}
  '';

  meta = with lib; {
    description = "TCP listener that opens URLs in the local browser";
    longDescription = ''
      A daemon that listens on a TCP port (default 7890) for URLs and opens
      them in the default browser. Designed to work with SSH RemoteForward
      to allow remote hosts to open URLs on the local Mac desktop.
    '';
    license = licenses.mit;
    platforms = platforms.darwin;
    maintainers = [];
  };
}
