{
  # Host-specific variables that can be imported and used across modules
  # Default values - override in hosts/<type>/<hostname>/variables.nix

  # Bot hosts - hosts that run AI/LLM bot services (moltbot, etc.)
  botHosts = ["nix-01" "nix-02" "nix-03"];

  # Darwin primary user - MUST be overridden per Darwin host
  # Required for nix-darwin system.primaryUser setting
  primaryUser = null; # Force override - no sensible default

  # NixOS state version - MUST be overridden per-host
  # This should match the NixOS version when the host was first installed
  # See: https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
  stateVersion = null; # Force override - no sensible default

  # ZFS host ID - required for ZFS hosts, null for non-ZFS hosts
  # Generate with: head -c 8 /etc/machine-id or od -An -tx4 -N4 /dev/urandom | tr -d ' '
  hostId = null;

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

  # Linux Builder (Darwin only)
  # Enable nix.linux-builder for building Linux packages on macOS
  linuxBuilderEnable = false;
}
