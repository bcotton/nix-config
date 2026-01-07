{
  lib,
  stdenv,
  makeWrapper,
  jq,
  bc,
  coreutils,
}:
stdenv.mkDerivation {
  pname = "arc-tab-archiver";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cp arc-tab-archiver.sh $out/bin/arc-tab-archiver
    chmod +x $out/bin/arc-tab-archiver

    # Wrap to include dependencies in PATH
    wrapProgram $out/bin/arc-tab-archiver \
      --prefix PATH : ${lib.makeBinPath [jq bc coreutils]}
  '';

  meta = with lib; {
    description = "Capture auto-archived Arc browser tabs to Obsidian vault";
    longDescription = ''
      A tool that reads Arc browser's archive data and saves auto-archived tabs
      to an Obsidian vault as markdown. Tracks processed tabs to avoid duplicates.

      Required environment variable:
        OBSIDIAN_FILE - Path to the Obsidian markdown file for output

      Optional environment variables:
        ARC_ARCHIVE - Path to Arc's StorableArchiveItems.json (default: ~/Library/Application Support/Arc/StorableArchiveItems.json)
        STATE_DIR - Directory for state file (default: ~/.local/state/arc-tab-archiver)
    '';
    license = licenses.mit;
    platforms = platforms.darwin;
    maintainers = [];
  };
}
