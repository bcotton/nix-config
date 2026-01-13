{
  lib,
  stdenv,
  makeWrapper,
  coreutils,
  bash,
}:
stdenv.mkDerivation {
  pname = "remote-notify";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cp remote-notify.sh $out/bin/remote-notify
    chmod +x $out/bin/remote-notify

    # Wrap to ensure timeout and bash are available
    # Uses bash's /dev/tcp for networking (no netcat needed)
    wrapProgram $out/bin/remote-notify \
      --prefix PATH : ${lib.makeBinPath [coreutils bash]}
  '';

  meta = with lib; {
    description = "Send notifications to remote Mac via SSH tunnel";
    longDescription = ''
      A utility that sends notifications through an SSH tunnel to display
      them on a remote desktop (typically a Mac). Falls back to local
      notify-send if the tunnel is not available.
    '';
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [];
  };
}
