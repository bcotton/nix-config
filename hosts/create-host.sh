#!/usr/bin/env bash
# Helper script to create a new host configuration
# Usage: ./create-host.sh <hostname> <type>
# Example: ./create-host.sh my-server nixos
# Example: ./create-host.sh my-mac darwin

set -e

HOSTNAME="$1"
TYPE="$2"

if [ -z "$HOSTNAME" ] || [ -z "$TYPE" ]; then
    echo "Usage: $0 <hostname> <type>"
    echo "  type: nixos or darwin"
    exit 1
fi

if [ "$TYPE" != "nixos" ] && [ "$TYPE" != "darwin" ]; then
    echo "Error: type must be 'nixos' or 'darwin'"
    exit 1
fi

HOST_DIR="hosts/$TYPE/$HOSTNAME"

if [ -d "$HOST_DIR" ]; then
    echo "Error: Host directory $HOST_DIR already exists"
    exit 1
fi

echo "Creating new $TYPE host: $HOSTNAME"
mkdir -p "$HOST_DIR"

# Create a basic default.nix
echo "Creating default.nix..."
if [ "$TYPE" = "nixos" ]; then
    cat > "$HOST_DIR/default.nix" << 'EOF'
{
  config,
  pkgs,
  lib,
  hostName,
  ...
}: let
  # Get merged variables (defaults + host overrides)
  commonLib = import ../../common/lib.nix;
  variables = commonLib.getHostVariables hostName;
in {
  imports = [
    # Include the results of the hardware scan.
    # Run: nixos-generate-config --show-hardware-config > hardware-configuration.nix
    ./hardware-configuration.nix
    
    # Add your module imports here
    # ../../../modules/some-module
  ];

  # Networking
  networking.hostName = hostName;
  networking.useDHCP = variables.useDHCP;
  
  # System configuration
  time.timeZone = variables.timeZone;
  programs.zsh.enable = variables.zshEnable;
  
  # Services
  services.openssh.enable = variables.opensshEnable;
  services.tailscale.enable = variables.tailscaleEnable;
  networking.firewall.enable = variables.firewallEnable;
  
  # Boot loader configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Don't change this value
  system.stateVersion = "23.11";
}
EOF
else
    cat > "$HOST_DIR/default.nix" << 'EOF'
{
  config,
  pkgs,
  lib,
  hostName,
  ...
}: let
  # Get merged variables (defaults + host overrides)
  commonLib = import ../../common/lib.nix;
  variables = commonLib.getHostVariables hostName;
in {
  imports = [
    # Add your module imports here
  ];

  # Networking
  networking.hostName = hostName;
  
  # System configuration
  time.timeZone = variables.timeZone;
  programs.zsh.enable = variables.zshEnable;
  
  # Services
  # Darwin-specific services go here
  
  # Don't change this value
  system.stateVersion = 4;
}
EOF
fi

echo "✅ Host directory created at: $HOST_DIR"
echo ""
echo "All hosts use defaults from hosts/common/variables.nix"
echo ""
echo "Next steps:"
echo "1. (Optional) Create $HOST_DIR/variables.nix to override any defaults:"
echo "   {"
echo "     timeZone = \"America/New_York\";"
echo "     firewallEnable = true;"
echo "   }"
echo ""
echo "2. Edit $HOST_DIR/default.nix to add host-specific configuration"
if [ "$TYPE" = "nixos" ]; then
    echo "3. Generate hardware config: nixos-generate-config --show-hardware-config > $HOST_DIR/hardware-configuration.nix"
fi
echo ""
echo "4. Add your host to flake.nix:"
if [ "$TYPE" = "nixos" ]; then
    echo "   nixosConfigurations = {"
    echo "     $HOSTNAME = nixosSystem \"x86_64-linux\" \"$HOSTNAME\" [\"username\"];"
    echo "     # ..."
    echo "   };"
else
    echo "   darwinConfigurations = {"
    echo "     $HOSTNAME = darwinSystem \"aarch64-darwin\" \"$HOSTNAME\" \"username\";"
    echo "     # ..."
    echo "   };"
fi
echo ""
echo "5. Build: nixos-rebuild switch --flake .#$HOSTNAME"
echo ""
echo "Note: If you don't create variables.nix, all defaults will be used!"

