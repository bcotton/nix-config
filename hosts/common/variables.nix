{
  # Host-specific variables that can be imported and used across modules
  # Default values - override in hosts/<type>/<hostname>/variables.nix

  # Network Configuration
  # Set to true to enable DHCP, false for static IP
  useDHCP = false;

  # Time Zone
  timeZone = "America/Denver";

  # Enable ZSH shell by default
  zshEnable = true;

  # Enable OpenSSH by default
  opensshEnable = true;

  # Firewall Configuration
  # TODO: Set to true once firewall rules are properly configured
  firewallEnable = false;

  # Tailscale Configuration
  tailscaleEnable = true;
}
