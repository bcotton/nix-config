{
  config,
  lib,
  nixosHostSpecs ? {},
  homepageServices ? {},
  ...
}: let
  service = "homepage-dashboard";
  cfg = config.services.clubcotton.homepage;
  clubcotton = config.clubcotton;
  port = toString config.services.${service}.listenPort;

  # Generate hosts from nixosHostSpecs - only include hosts with an IP
  # Filter first (hosts with IP), then map to expected format
  hostsWithIp = lib.filterAttrs (_name: spec: spec.ip or null != null) nixosHostSpecs;
  hostsFromSpecs =
    lib.mapAttrs (
      name: spec: {
        ip = spec.ip;
        displayName = spec.displayName or name;
        glancesPort = spec.glancesPort or 61208;
        icon = spec.icon or "mdi-server";
      }
    )
    hostsWithIp;

  # Generate services from homepageServices spec
  # Services with tailnetHostname get URLs constructed from tailnetDomain
  # Services with explicit href use that URL directly
  servicesFromSpecs =
    lib.mapAttrs (
      _name: spec: {
        inherit (spec) name description icon category;
        href =
          if spec.href or null != null
          then spec.href
          else "https://${spec.tailnetHostname}.${cfg.tailnetDomain}";
        widget = spec.widget or null;
      }
    )
    homepageServices;
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

    tailnetHostname = lib.mkOption {
      type = lib.types.str;
      default = "home";
      description = "Tailnet hostname to expose homepage as";
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
          icon = lib.mkOption {
            type = lib.types.str;
            default = "mdi-server";
            description = "Icon for the host";
          };
        };
      });
      default = hostsFromSpecs;
      description = "Hosts to monitor with Glances. Auto-populated from nixosHostSpecs.";
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
      default = servicesFromSpecs;
      description = "Services to display on the homepage. Auto-populated from homepageServices in flake-modules/hosts.nix.";
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
      openFirewall = true;
      # Include both with and without port for flexibility
      allowedHosts = lib.concatStringsSep "," [
        "localhost"
        "localhost:${port}"
        "127.0.0.1"
        "127.0.0.1:${port}"
        "admin"
        "admin:${port}"
        "admin.lan"
        "admin.lan:${port}"
        "192.168.5.98"
        "192.168.5.98:${port}"
        "${cfg.tailnetHostname}.${cfg.tailnetDomain}"
      ];
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
        # Dark theme settings
        theme = "dark";
        color = "slate";
        cardBlur = "sm";
        background = {
          color = "rgb(30, 41, 59)"; # slate-800
        };

        layout = [
          {
            Hosts = {
              header = true;
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

        # Build Hosts section with links to Glances UI and system info widget
        hostServices =
          lib.mapAttrsToList (
            _hostname: hostCfg: {
              "${hostCfg.displayName}" = {
                icon = hostCfg.icon;
                href = "http://${hostCfg.ip}:${toString hostCfg.glancesPort}";
                description = "System monitoring";
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
        # Build list of category objects
        [{Hosts = hostServices;}]
        ++ (lib.map (cat: {"${cat}" = categoryServices cat;}) categories)
        ++ [{Misc = cfg.misc;}];
    };

    # Expose homepage on tailnet
    services.tsnsrv = {
      enable = true;
      defaults.authKeyPath = clubcotton.tailscaleAuthKeyPath;

      services."${cfg.tailnetHostname}" = {
        ephemeral = true;
        toURL = "http://127.0.0.1:${port}/";
      };
    };
  };
}
