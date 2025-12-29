{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  service = "nix-cache-proxy";
  cfg = config.services.clubcotton.${service};
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "Nix cache proxy with upstream caching";

    port = mkOption {
      type = types.port;
      default = 80;
      description = "Port for nginx to listen on";
    };

    bindAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "IP address to bind to";
    };

    harmoniaBind = mkOption {
      type = types.str;
      default = "127.0.0.1:5000";
      description = "Harmonia backend address";
    };

    upstreamCache = mkOption {
      type = types.str;
      default = "https://cache.nixos.org";
      description = "Upstream cache URL to proxy and cache";
    };

    cachePath = mkOption {
      type = types.path;
      default = "/ssdpool/local/nix-cache-proxy";
      description = "Path to store cached upstream packages";
    };

    cacheMaxSize = mkOption {
      type = types.str;
      default = "100g";
      description = "Maximum cache size (e.g., '100g', '500g')";
    };

    cacheValidTime = mkOption {
      type = types.str;
      default = "30d";
      description = "How long to cache upstream responses";
    };

    tailnetHostname = mkOption {
      type = types.nullOr types.str;
      default = "nix-cache";
      description = "The tailnet hostname to expose the cache proxy as";
    };
  };

  config = mkIf cfg.enable {
    # Ensure cache directory exists
    systemd.tmpfiles.rules = [
      "d ${cfg.cachePath} 0755 nginx nginx - -"
    ];

    # Configure nginx as caching proxy
    services.nginx = {
      enable = true;

      appendHttpConfig = ''
        # Proxy cache configuration
        proxy_cache_path ${cfg.cachePath}
          levels=1:2
          keys_zone=nix_cache:10m
          max_size=${cfg.cacheMaxSize}
          inactive=90d
          use_temp_path=off;
      '';

      virtualHosts."nix-cache" = {
        listen = [
          {
            addr = cfg.bindAddress;
            port = cfg.port;
          }
        ];

        locations."/" = {
          extraConfig = ''
            # Try Harmonia first for local builds
            proxy_pass http://${cfg.harmoniaBind};
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header Connection "";

            # On 404 from Harmonia, try upstream cache
            proxy_intercept_errors on;
            error_page 404 = @upstream;
          '';
        };

        locations."@upstream" = {
          extraConfig = let
            upstreamHost = builtins.replaceStrings ["https://" "http://"] ["" ""] cfg.upstreamCache;
          in ''
            # Use Google DNS for resolution (IPv4 only)
            resolver 8.8.8.8 ipv4=on ipv6=off;

            # Set upstream as variable to force runtime DNS resolution
            set $upstream_url "${cfg.upstreamCache}$request_uri";

            # Proxy to upstream cache using variable (forces runtime DNS resolution)
            proxy_pass $upstream_url;
            proxy_http_version 1.1;
            proxy_set_header Host ${upstreamHost};
            proxy_set_header Connection "";
            proxy_ssl_server_name on;

            # Enable caching
            proxy_cache nix_cache;
            proxy_cache_valid 200 ${cfg.cacheValidTime};
            proxy_cache_valid 404 1m;
            proxy_cache_key "$request_uri";
            proxy_cache_lock on;
            proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;

            # Headers for cache debugging
            add_header X-Cache-Status $upstream_cache_status;

            # Ignore client cache control headers
            proxy_ignore_headers Cache-Control Expires;
          '';
        };
      };
    };

    # Open firewall for cache proxy
    networking.firewall.allowedTCPPorts = [cfg.port];

    # Ensure Harmonia is enabled (dependency)
    assertions = [
      {
        assertion = cfg.enable -> config.services.clubcotton.harmonia.enable;
        message = "nix-cache-proxy requires harmonia to be enabled";
      }
    ];
  };
}
