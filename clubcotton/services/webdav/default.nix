{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.clubcotton.webdav;
  # clubcotton = config.clubcotton; # this fails in tests with the following error aka fuckery
  #
  # error: attribute 'clubcotton' missing
  #      at /nix/store/yvfs8vs5bnalv8i8iwqq2qlnp810h4yn-source/clubcotton/services/webdav/default.nix:9:16:
  #           8|   cfg = config.services.clubcotton.webdav;
  #           9|   clubcotton = config.clubcotton;
  #            |                ^
  #          10|
  #
  # This is likely because the nixos-test function creates and passes in a brand
  # new "config" which doesn't include clubcotton/default.nix

  # Submodule for user configuration
  userModule = types.submodule {
    options = {
      password = mkOption {
        type = types.str;
        description = "Password for WebDAV authentication";
        example = "your-secure-password";
      };

      directory = mkOption {
        type = types.str;
        description = "Directory path to serve via WebDAV";
        example = "/media/webdav/files";
      };

      permissions = mkOption {
        type = types.str;
        default = "CRUD";
        description = ''
          Access permissions for the user:
            R    = Read only
            CRUD = Create, Read, Update, Delete
        '';
      };
    };
  };
in {
  options.services.clubcotton.webdav = {
    enable = mkEnableOption "WebDAV server";

    users = mkOption {
      type = types.attrsOf userModule;
      default = {};
      description = "Attribute set of WebDAV users and their configurations";
      example = literalExpression ''
        {
          user1 = {
            password = "pass1";
            directory = "/media/webdav/user1";
            permissions = "CRUD";
          };
          user2 = {
            password = "pass2";
            directory = "/media/webdav/user2";
            permissions = "R";
          };
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    services.webdav = {
      enable = true;
      settings = {
        address = "0.0.0.0";
        port = 6065;
        prefix = "/";
        debug = "false";
        log = {
          format = "console";
          colors = true;
          outputs = ["stderr"];
        };
        permissions = "none";
        rulesBehavior = "overwrite";
        users =
          mapAttrsToList
          (name: user: {
            username = name;
            inherit (user) password directory permissions;
          })
          cfg.users;
      };
    };
  };
}
