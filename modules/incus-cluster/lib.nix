# Helper functions for incus-cluster module
# Currently minimal — expand as needed for image building, status checking, etc.
{lib}: {
  # Generate a hardware-configuration.nix import path for an incus instance
  containerHardwareModule = nixpkgs: "${nixpkgs}/nixos/modules/virtualisation/lxc-container.nix";
  vmHardwareModule = nixpkgs: "${nixpkgs}/nixos/modules/virtualisation/incus-virtual-machine.nix";
}
