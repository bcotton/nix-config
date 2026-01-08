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
      to an Obsidian vault as markdown tables, organized by Arc space.

      Creates one file per space (e.g., Grafana.md, Home Lab.md) with a table
      of archived tabs sorted by date (newest first).

      Required environment variable:
        OBSIDIAN_DIR - Directory for output files (e.g., ~/vault/arc-archive)

      Optional environment variables:
        ARC_DIR - Path to Arc's data directory (default: ~/Library/Application Support/Arc)
        STATE_DIR - Directory for state file (default: ~/.local/state/arc-tab-archiver)
    '';
    license = licenses.mit;
    platforms = platforms.darwin;
    maintainers = [];
  };
}
