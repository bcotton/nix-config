# Library of functions for generating Prometheus scrape configurations
{lib}: let
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
  ];

  # Find all enabled exporters for a given host
  # Args:
  #   hostName: The name of the host to check
  #   host: The NixOS configuration for the host
  # Returns: Attribute set of enabled exporters and their configurations
  enabledExportersF = hostName: host: let
    exporters = host.config.services.prometheus.exporters;
    mkExporter = name:
      if
        builtins.hasAttr name exporters
        && builtins.isAttrs exporters.${name}
        && exporters.${name}.enable or false
      then {${name} = exporters.${name};}
      else {};
  in
    lib.foldl' (acc: name: acc // (mkExporter name)) {} monitoredExporters;

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
in {
  # Functions for working with exporters
  inherit monitoredExporters enabledExportersF mkScrapeConfigExporterF;
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

    # Generate blackbox configs for tsnsrv services
    tsnsrvBlackboxConfigs = lib.flatten (
      lib.mapAttrsToList (hostname: services: mkTsnsrvBlackboxConfigF hostname services tsnsrvExcludeList) enabledTsnsrvServices
    );
  in {
    # Export all generated configurations
    inherit tsnsrvBlackboxConfigs;

    # Combine all auto-generated scrape configs
    autogenScrapeConfigs =
      lib.flatten (map builtins.attrValues (builtins.attrValues scrapeConfigsByHost));
  };
}
