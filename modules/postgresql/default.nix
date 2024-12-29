{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.clubcotton.postgresql;
in {
  imports = [
    ./immich.nix
    ./open-webui.nix
  ];

  options.services.clubcotton.postgresql = {
    enable = mkEnableOption "PostgreSQL Server";

    postStartCommands = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Commands to run after PostgreSQL starts.";
      internal = true;
    };

    package = mkOption {
      type = types.package;
      default = pkgs.postgresql_16;
      defaultText = literalExpression "pkgs.postgresql_16";
      description = "PostgreSQL package to use.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/postgresql/${cfg.package.psqlSchema}";
      defaultText = literalExpression ''"/var/lib/postgresql/''${config.services.clubcotton.postgresql.package.psqlSchema}"'';
      description = "Data directory for PostgreSQL.";
    };

    port = mkOption {
      type = types.port;
      default = 5432;
      description = "The port on which PostgreSQL listens.";
    };

    enableTCPIP = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether PostgreSQL should listen on all network interfaces.
        If disabled, the database can only be accessed via its Unix
        domain socket or via TCP connections to localhost.
      '';
    };

    authentication = mkOption {
      type = types.lines;
      default = ''
        # Generated file; do not edit!
        local all all                trust
        host  all all 192.168.5.0/24 scram-sha-256
        host  all all 127.0.0.1/32   scram-sha-256
        host  all all ::1/128        scram-sha-256
      '';
      description = ''
        Defines how users authenticate themselves to the server.
        By default, peer authentication is used for local connections,
        and md5 password authentication for TCP connections.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      package = cfg.package;
      dataDir = cfg.dataDir;
      enableTCPIP = cfg.enableTCPIP;
      authentication = cfg.authentication;
      settings = {
        port = cfg.port;
        listen_addresses =
          if cfg.enableTCPIP
          then "*"
          else "localhost";
        password_encryption = "scram-sha-256";
      };
    };

    systemd.services.postgresql.postStart = mkIf (cfg.postStartCommands != []) ''
      ${concatStringsSep "\n" cfg.postStartCommands}
    '';
  };
}
