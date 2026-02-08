# Library of functions for generating Prometheus scrape configurations
{lib}: let
  # Import host variables library for reading per-host settings
  commonLib = import ../../hosts/common/lib.nix;

  # Common domain suffix for tailscale services
  tailscaleDomain = ".bobtail-clownfish.ts.net";

  /*
  * Exporter-related functions
  * These functions handle the discovery and configuration of Prometheus exporters
  * across NixOS hosts in the fleet.
  */

  # List of exporters to monitor across all hosts
  monitoredExporters = [
    "node"
    "zfs"
    "postgres"
    "smartctl"
  ];

  # Find all enabled exporters for a given host
  # Args:
  #   hostName: The name of the host to check
  #   host: The NixOS configuration for the host
  # Returns: Attribute set of enabled exporters and their configurations
  #          Returns empty set if shouldScrapeMetrics is false for the host
  enabledExportersF = hostName: host: let
    variables = commonLib.getHostVariables hostName;
    shouldScrape = variables.shouldScrapeMetrics or true;
    exporters = host.config.services.prometheus.exporters;
    mkExporter = name:
      if
        builtins.hasAttr name exporters
        && builtins.isAttrs exporters.${name}
        && exporters.${name}.enable or false
      then {${name} = exporters.${name};}
      else {};
  in
    if shouldScrape
    then lib.foldl' (acc: name: acc // (mkExporter name)) {} monitoredExporters
    else {};

  # Build the scrape config for a specific exporter on a host
  # Args:
  #   hostname: The name of the host
  #   ename: The name of the exporter
  #   ecfg: The exporter's configuration
  # Returns: Scrape configuration for the exporter
  mkScrapeConfigExporterF = hostname: ename: ecfg: {
    job_name = "${hostname}-${ename}";
    scrape_interval = "30s";
    static_configs = [{targets = ["${hostname}:${toString ecfg.port}"];}];
    relabel_configs = [
      {
        target_label = "instance";
        replacement = "${hostname}";
      }
      {
        target_label = "job";
        replacement = "${ename}";
      }
    ];
  };

  /*
  * Tailscale-related functions
  * These functions handle the discovery and configuration of Tailscale metrics
  * for hosts with Tailscale enabled.
  */

  # Check which hosts have tailscale enabled
  # Args:
  #   hostName: The name of the host to check
  #   host: The NixOS configuration for the host
  # Returns: Boolean indicating if tailscale is enabled
  #          Returns false if shouldScrapeMetrics is false for the host
  enabledTailscaleF = hostName: host: let
    variables = commonLib.getHostVariables hostName;
    shouldScrape = variables.shouldScrapeMetrics or true;
  in
    if shouldScrape && (host.config.services.clubcotton.services.tailscale.enable or false)
    then true
    else false;

  # Generate scrape configs for tailscale metrics
  # Args:
  #   hostname: The name of the host
  #   enabled: Boolean indicating if tailscale is enabled
  # Returns: List of scrape configurations for tailscale metrics
  mkTailscaleScrapeConfigF = hostname: enabled:
    if enabled
    then [
      {
        job_name = "${hostname}-tailscale";
        scrape_interval = "30s";
        static_configs = [{targets = ["${hostname}:5252"];}];
        relabel_configs = [
          {
            target_label = "instance";
            replacement = "${hostname}";
          }
          {
            target_label = "job";
            replacement = "tailscale";
          }
        ];
      }
    ]
    else [];

  /*
  * Tsnsrv-related functions
  * These functions handle the discovery and configuration of services exposed
  * through tsnsrv (Tailscale-based service exposure).
  */

  # Check which hosts have tsnsrv services configured
  # Args:
  #   hostName: The name of the host to check
  #   host: The NixOS configuration for the host
  # Returns: Attribute set of configured tsnsrv services
  enabledTsnsrvServicesF = hostName: host:
    host.config.services.tsnsrv.services or {};

  # Generate blackbox scrape configs for tsnsrv services
  # Args:
  #   hostname: The name of the host
  #   services: Attribute set of tsnsrv services
  #   excludeList: Optional list of service names to exclude from monitoring
  # Returns: List of blackbox exporter targets for the services
  mkTsnsrvBlackboxConfigF = hostname: services: excludeList:
    lib.mapAttrsToList (name: _: {
      targets = ["https://${name}${tailscaleDomain}"];
    })
    (lib.filterAttrs
      (name: _:
        !(builtins.elem name (
          if excludeList == null
          then []
          else excludeList
        )))
      services);
in {
  # Export the domain constant
  inherit tailscaleDomain;

  # Functions for working with exporters
  inherit monitoredExporters enabledExportersF mkScrapeConfigExporterF;

  # Functions for working with tailscale
  inherit enabledTailscaleF mkTailscaleScrapeConfigF;

  # Functions for working with tsnsrv
  inherit enabledTsnsrvServicesF mkTsnsrvBlackboxConfigF;

  /*
  * Helper functions for generating complete scrape configurations
  */

  # Generate complete scrape configurations for all monitored services
  # Args:
  #   self: The flake's self reference containing nixosConfigurations
  #   tsnsrvExcludeList: Optional list of tsnsrv services to exclude from monitoring
  # Returns: List of all scrape configurations
  mkScrapeConfigs = self: tsnsrvExcludeList: let
    # Get all enabled exporters across hosts
    enabledExporters = builtins.mapAttrs enabledExportersF self.nixosConfigurations;

    # Build scrape configs for each host's exporters
    mkScrapeConfigHost = name: exporters:
      builtins.mapAttrs (mkScrapeConfigExporterF name) exporters;
    scrapeConfigsByHost = builtins.mapAttrs mkScrapeConfigHost enabledExporters;

    # Get tailscale status for all hosts
    enabledTailscale = builtins.mapAttrs enabledTailscaleF self.nixosConfigurations;

    # Generate tailscale scrape configs
    tailscaleScrapeConfigs = lib.flatten (builtins.attrValues (builtins.mapAttrs mkTailscaleScrapeConfigF enabledTailscale));

    # Get tsnsrv services for all hosts
    enabledTsnsrvServices = builtins.mapAttrs enabledTsnsrvServicesF self.nixosConfigurations;

    # Generate blackbox configs for tsnsrv services
    tsnsrvBlackboxConfigs = lib.flatten (
      lib.mapAttrsToList (hostname: services: mkTsnsrvBlackboxConfigF hostname services tsnsrvExcludeList) enabledTsnsrvServices
    );
  in {
    # Export all generated configurations
    inherit tsnsrvBlackboxConfigs;

    # Combine all auto-generated scrape configs
    autogenScrapeConfigs =
      lib.flatten (map builtins.attrValues (builtins.attrValues scrapeConfigsByHost))
      ++ tailscaleScrapeConfigs;
  };
}
