{
  lib,
  stdenv,
  makeWrapper,
  socat,
}:
stdenv.mkDerivation {
  pname = "clipboard-receiver";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cp clipboard-receiver.sh $out/bin/clipboard-receiver
    chmod +x $out/bin/clipboard-receiver

    # Wrap to include socat in PATH
    wrapProgram $out/bin/clipboard-receiver \
      --prefix PATH : ${lib.makeBinPath [socat]}
  '';

  meta = with lib; {
    description = "TCP listener that copies received text to the local clipboard";
    longDescription = ''
      A daemon that listens on a TCP port (default 7891) for text and copies
      it to the system clipboard via pbcopy. Designed to work with SSH RemoteForward
      to allow remote hosts to copy text to the local Mac clipboard.
    '';
    license = licenses.mit;
    platforms = platforms.darwin;
    maintainers = [];
  };
}
