# Example module showing how to use the variable system
# This can be placed in modules/ directory
{
  config,
  pkgs,
  lib,
  hostName,
  ...
}: let
  # Get merged variables (defaults + host overrides)
  commonLib = import ../hosts/common/lib.nix;
  variables = commonLib.getHostVariables hostName;
in {
  # Example: conditionally configure based on variables

  # Time zone from variables
  time.timeZone = variables.timeZone;

  # ZSH configuration
  programs.zsh.enable = variables.zshEnable;

  # SSH configuration
  services.openssh = {
    enable = variables.opensshEnable;
    settings = {
      PermitRootLogin = lib.mkDefault "prohibit-password";
      PasswordAuthentication = lib.mkDefault false;
    };
  };

  # Tailscale configuration
  # Note: tailscale is now enabled via common config in flake-modules/hosts.nix
  # using services.clubcotton.tailscale.enable = variables.tailscaleEnable
  # Only set this if you need to override routing features:
  # services.clubcotton.tailscale.useRoutingFeatures = "server";

  # Firewall configuration
  networking.firewall = {
    enable = variables.firewallEnable;
    # Add common firewall rules when enabled
    allowedTCPPorts = lib.mkIf variables.firewallEnable [
      22 # SSH
    ];
  };

  # Network configuration
  networking.useDHCP = lib.mkDefault variables.useDHCP;

  # Example: conditional imports based on variables
  # imports = lib.optionals variables.someFeatureEnable [
  #   ./some-feature.nix
  # ];
}
