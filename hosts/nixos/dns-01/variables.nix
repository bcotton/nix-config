{
  # Host-specific variable overrides for dns-01
  # Only include values that differ from hosts/common/variables.nix
  stateVersion = "23.11";

  # Enable firewall - dns-01 is the first host to test firewall enablement
  # Technitium module already opens ports 53 TCP/UDP and the web console port
  firewallEnable = true;
}
