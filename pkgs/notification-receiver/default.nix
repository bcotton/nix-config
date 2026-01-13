{
  lib,
  stdenv,
  makeWrapper,
  socat,
}:
stdenv.mkDerivation {
  pname = "notification-receiver";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cp notification-receiver.sh $out/bin/notification-receiver
    chmod +x $out/bin/notification-receiver

    # Wrap to include socat in PATH
    wrapProgram $out/bin/notification-receiver \
      --prefix PATH : ${lib.makeBinPath [socat]}
  '';

  meta = with lib; {
    description = "TCP listener that displays macOS notifications";
    longDescription = ''
      A daemon that listens on a TCP port (default 7892) for notification
      data and displays them using macOS osascript. Designed to work with
      SSH RemoteForward to allow remote hosts to send notifications to
      the local Mac desktop.
    '';
    license = licenses.mit;
    platforms = platforms.darwin;
    maintainers = [];
  };
}
