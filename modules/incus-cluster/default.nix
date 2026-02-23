{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  imports = [
    ./profiles.nix
    ./instances.nix
    ./controller.nix
  ];

  options.services.incus-cluster = {
    enable = mkEnableOption "Declarative Incus cluster instance management";

    site = mkOption {
      type = types.str;
      description = "Site name for this controller host (e.g. clubcotton, condo, natalya).";
      example = "clubcotton";
    };
  };

  config = mkIf config.services.incus-cluster.enable {
    assertions = [
      {
        assertion = config.virtualisation.incus.enable;
        message = "services.incus-cluster requires virtualisation.incus.enable = true";
      }
    ];
  };
}
