# Library functions for nix-config
{
  # Merge default variables with host-specific overrides
  # Usage in host configs: lib.getHostVariables hostName
  # Automatically checks both nixos/ and darwin/ subdirectories
  getHostVariables = hostName: let
    defaults = import ./variables.nix;

    # Check both nixos and darwin directories for host-specific overrides
    nixosVarsPath = ../nixos/${hostName}/variables.nix;
    darwinVarsPath = ../darwin/${hostName}/variables.nix;

    overrides =
      if builtins.pathExists nixosVarsPath
      then import nixosVarsPath
      else if builtins.pathExists darwinVarsPath
      then import darwinVarsPath
      else {};
  in
    defaults // overrides;
}
