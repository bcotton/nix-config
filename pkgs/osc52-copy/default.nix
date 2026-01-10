{
  lib,
  stdenv,
  makeWrapper,
  coreutils,
  bash,
  tmux,
}:
stdenv.mkDerivation {
  pname = "osc52-copy";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cp osc52-copy.sh $out/bin/osc52-copy
    chmod +x $out/bin/osc52-copy

    # Wrap to ensure dependencies are available
    wrapProgram $out/bin/osc52-copy \
      --prefix PATH : ${lib.makeBinPath [coreutils bash tmux]}
  '';

  meta = with lib; {
    description = "Copy to clipboard via OSC52 escape sequence";
    longDescription = ''
      A utility that copies text to the system clipboard using OSC52
      terminal escape sequences. Works through SSH and nested tmux sessions.
    '';
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [];
  };
}
