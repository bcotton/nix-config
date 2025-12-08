{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.programs.beets-cli;
in {
  options.programs.beets-cli = {
    enable = lib.mkEnableOption "Beets";
  };

  # inspired by https://github.com/Ramblurr/nixcfg/blob/b7775869ec34820c1889196e411221205a79db19/hosts/mali/beets.nix
  config = lib.mkIf cfg.enable {
    programs.beets = {
      enable = true;
      package = pkgs.beets-unstable;
      settings = {
        directory = "/media/music/curated";
        library = "/media/music/musiclibrary.db";
        plugins = [
          "spotify"
          "info"
          "fetchart"
          "lyrics"
          "lastgenre"
          "id3extract"
          "duplicates"
          "fromfilename"
          "mbsync"
        ];

        import = {
          move = true;
          copy = false;
        };

        spotify = {
          source_weight = 0;
          mode = "open";
          region_filter = "US";
          show_failures = "on";
          tiebreak = "first";
        };

        ignored = ["missing_tracks" "track_length" "unmatched_tracks" "track_index"];

        musicbrainz = {
          enabled = true;
          host = "musicbrainz.org";
          https = false;
          ratelimit = 1;
          ratelimit_interval = 1;
          searchlimit = 5;
          extra_tags = [];
          genres = true;
          external_ids = {
            discogs = true;
            bandcamp = true;
            spotify = true;
            deezer = true;
            beatport = true;
            tidal = true;
            youtube = true;
          };
        };
        id3extract = {
          mappings = {
            WOAS = "spotify_track_id";
          };
        };
      };
    };
  };
}
