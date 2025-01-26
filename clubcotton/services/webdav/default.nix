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

      rules = mkOption {
        type = types.listOf (types.submodule {
          options = {
            path = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Path to apply permissions to";
              example = "/media/files";
            };
            regex = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Regular expression to match paths";
              example = "^.+\\.mp4$";
            };
            permissions = mkOption {
              type = types.str;
              description = "Permissions for this rule (none, R, RU, CRUD)";
              example = "R";
            };
          };
        });
        default = [];
        description = "List of path/regex rules with specific permissions";
        example = [
          {
            path = "/media/files";
            permissions = "R";
          }
          {
            regex = "^.+\\.mp4$";
            permissions = "R";
          }
        ];
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
          # Basic user with full access to their directory
          user1 = {
            password = "pass1";
            directory = "/media/webdav/user1";
            permissions = "CRUD";
          };
          # User with read-only base permissions and specific rules
          media-readonly = {
            password = "pass2";
            directory = "/media";
            permissions = "none";  # Default to no access
            rules = [
              {
                path = "/media";  # Allow read access to media directory
                permissions = "R";
              }
              {
                regex = "^.+\\.(mp4|mkv)$";  # Read-only access to video files
                permissions = "R";
              }
            ];
          };
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = all (user: all (rule: 
          (rule.path != null) != (rule.regex != null)
        ) user.rules) (attrValues cfg.users);
        message = "Each rule must have exactly one of path or regex set";
      }
    ];

    services.webdav = {
      enable = true;
      group = "share";
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
            rules = map (rule: 
              filterAttrs (n: v: v != null) {
                inherit (rule) permissions;
                path = rule.path;
                regex = rule.regex;
              }
            ) user.rules;
          })
          cfg.users;
      };
    };
  };
}
