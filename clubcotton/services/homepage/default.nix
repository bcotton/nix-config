{
  config,
  lib,
  ...
}: let
  service = "homepage-dashboard";
  cfg = config.services.clubcotton.homepage;
in {
  options.services.clubcotton.homepage = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };

    tailnetDomain = lib.mkOption {
      type = lib.types.str;
      default = "bobtail-clownfish.ts.net";
      description = "Tailscale domain for service URLs";
    };

    hosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          ip = lib.mkOption {
            type = lib.types.str;
            description = "IP address for Glances monitoring";
          };
          displayName = lib.mkOption {
            type = lib.types.str;
            description = "Display name for the host in Glances widget";
          };
          glancesPort = lib.mkOption {
            type = lib.types.port;
            default = 61208;
            description = "Port for Glances service";
          };
        };
      });
      default = {};
      description = "Hosts to monitor with Glances";
    };

    services = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Display name for the service";
          };
          description = lib.mkOption {
            type = lib.types.str;
            description = "Service description";
          };
          icon = lib.mkOption {
            type = lib.types.str;
            description = "Icon for the service (e.g., 'jellyfin.svg')";
          };
          category = lib.mkOption {
            type = lib.types.str;
            description = "Category for grouping (Arr, Media, Downloads, Content, Infrastructure, Monitoring)";
          };
          href = lib.mkOption {
            type = lib.types.str;
            description = "URL for the service";
          };
          widget = lib.mkOption {
            type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
            default = null;
            description = "Optional widget configuration for API integration";
          };
        };
      });
      default = {};
      description = "Services to display on the homepage";
    };

    bookmarks = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [];
      description = "Bookmarks to display in the header";
    };

    misc = lib.mkOption {
      default = [];
      type = lib.types.listOf (
        lib.types.attrsOf (
          lib.types.submodule {
            options = {
              description = lib.mkOption {
                type = lib.types.str;
              };
              href = lib.mkOption {
                type = lib.types.str;
              };
              siteMonitor = lib.mkOption {
                type = lib.types.str;
                default = "";
              };
              icon = lib.mkOption {
                type = lib.types.str;
              };
            };
          }
        )
      );
      description = "Miscellaneous services to display";
    };
  };

  config = lib.mkIf cfg.enable {
    services.glances.enable = true;

    services.${service} = {
      enable = true;
      customCSS = ''
        body, html {
          font-family: SF Pro Display, Helvetica, Arial, sans-serif !important;
        }
        .font-medium {
          font-weight: 700 !important;
        }
        .font-light {
          font-weight: 500 !important;
        }
        .font-thin {
          font-weight: 400 !important;
        }
        #information-widgets {
          padding-left: 1.5rem;
          padding-right: 1.5rem;
        }
        div#footer {
          display: none;
        }
        .services-group.basis-full.flex-1.px-1.-my-1 {
          padding-bottom: 3rem;
        };
      '';

      bookmarks = cfg.bookmarks;

      settings = {
        layout = [
          {
            Glances = {
              header = false;
              style = "row";
              columns = 4;
            };
          }
          {
            Arr = {
              header = true;
              style = "column";
            };
          }
          {
            Downloads = {
              header = true;
              style = "column";
            };
          }
          {
            Media = {
              header = true;
              style = "column";
            };
          }
          {
            Content = {
              header = true;
              style = "column";
            };
          }
          {
            Infrastructure = {
              header = true;
              style = "column";
            };
          }
          {
            Monitoring = {
              header = true;
              style = "column";
            };
          }
          {
            "Smart Home" = {
              header = true;
              style = "column";
            };
          }
          {
            Misc = {
              header = true;
              style = "column";
            };
          }
        ];
        headerStyle = "clean";
        statusStyle = "dot";
        hideVersion = "true";
      };

      services = let
        # Group services by category
        categories = ["Arr" "Media" "Downloads" "Content" "Infrastructure" "Monitoring"];

        servicesByCategory = category:
          lib.filterAttrs (_name: svc: svc.category == category) cfg.services;

        # Convert a service config to homepage format
        serviceToHomepage = _name: svc: {
          "${svc.name}" =
            {
              icon = svc.icon;
              description = svc.description;
              href = svc.href;
              siteMonitor = svc.href;
            }
            // lib.optionalAttrs (svc.widget != null) {
              widget = svc.widget;
            };
        };

        # Build homepage services list for a category
        categoryServices = category: let
          svcs = servicesByCategory category;
        in
          lib.mapAttrsToList serviceToHomepage svcs;
      in
        # Build list of category objects
        (lib.map (cat: {"${cat}" = categoryServices cat;}) categories)
        ++ [{Misc = cfg.misc;}]
        ++ [
          {
            Glances = let
              # Build Glances widgets for all configured hosts
              hostWidgets =
                lib.mapAttrsToList (
                  hostname: hostCfg: {
                    "${hostCfg.displayName}" = {
                      widget = {
                        type = "glances";
                        url = "http://${hostCfg.ip}:${toString hostCfg.glancesPort}";
                        metric = "info";
                        chart = false;
                        version = 4;
                      };
                    };
                  }
                )
                cfg.hosts;
            in
              # If no hosts configured, use localhost
              if cfg.hosts == {}
              then let
                port = toString config.services.glances.port;
              in [
                {
                  Info = {
                    widget = {
                      type = "glances";
                      url = "http://localhost:${port}";
                      metric = "info";
                      chart = false;
                      version = 4;
                    };
                  };
                }
                {
                  "CPU Temp" = {
                    widget = {
                      type = "glances";
                      url = "http://localhost:${port}";
                      metric = "sensor:Package id 0";
                      chart = false;
                      version = 4;
                    };
                  };
                }
                {
                  Processes = {
                    widget = {
                      type = "glances";
                      url = "http://localhost:${port}";
                      metric = "process";
                      chart = false;
                      version = 4;
                    };
                  };
                }
                {
                  Network = {
                    widget = {
                      type = "glances";
                      url = "http://localhost:${port}";
                      metric = "network:enp2s0";
                      chart = false;
                      version = 4;
                    };
                  };
                }
              ]
              else hostWidgets;
          }
        ];
    };
  };
}
