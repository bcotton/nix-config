{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.clubcotton.kavita;
in {
  options.services.clubcotton.kavita = {
    enable = mkEnableOption "Kavita server";

    port = mkOption {
      type = types.port;
      default = 8085;
      description = "Port to listen on";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/kavita/data";
      description = "Directory where Kavita stores its data";
    };

    libraryDir = mkOption {
      type = types.str;
      default = "/var/lib/kavita/library";
      description = "Directory where Kavita stores its libraries";
    };

    user = mkOption {
      type = types.str;
      default = "kavita";
      description = "User account under which Kavita runs";
    };

    tokenKeyFile = mkOption {
      type = types.path;
      description = ''
        A file containing the TokenKey (a secret with 512+ bits).
        Generate with: head -c 64 /dev/urandom | base64 --wrap=0
      '';
    };

    bindAddresses = mkOption {
      type = types.listOf types.str;
      default = ["0.0.0.0" "::"];
      description = "IP addresses to bind to (IPv4 and IPv6)";
    };

    tailnetHostname = mkOption {
      type = types.str;
      default = "";
      description = "The tailnet hostname to expose Kavita as";
    };

    sharedUsers = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of users who should have access to the Kavita libraries";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Kavita";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Digital library for comics, manga, and books";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "kavita.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Media";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Create the library directory with appropriate permissions:
      # - 0775 means rwxrwxr-x
      # - Owner (kavita user) gets full access (rwx)
      # - Group (kavita group) gets full access (rwx)
      # - Others get read and execute (r-x)
      systemd.tmpfiles.rules = [
        "d '${cfg.libraryDir}' 0775 ${cfg.user} ${cfg.user} - -"
      ];

      # Configure the upstream Kavita service
      # Note: The kavita group is created by the upstream module
      services.kavita = {
        enable = true;
        inherit (cfg) user dataDir tokenKeyFile;
        settings = {
          Port = cfg.port;
          IpAddresses = concatStringsSep "," cfg.bindAddresses;
        };
      };
    }

    # Note: Tailscale/tsnsrv integration should be configured separately
    # in host configurations where clubcotton config is available.
    # Example:
    #   services.tsnsrv = {
    #     enable = true;
    #     defaults.authKeyPath = config.clubcotton.tailscaleAuthKeyPath;
    #     services."kavita.example.com" = {
    #       ephemeral = true;
    #       toURL = "http://localhost:${toString config.services.clubcotton.kavita.port}/";
    #     };
    #   };

    # Add specified users to the kavita group to grant them
    # shared access to the libraries through group permissions
    # users.users = let
    #   makeKavitaUser = user: {
    #     "${user}" = {
    #       extraGroups = [ "kavita" ];
    #     };
    #   };
    # in mkMerge (map makeKavitaUser cfg.sharedUsers);
  ]);
}
