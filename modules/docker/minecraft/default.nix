# Auto-generated using compose2nix v0.1.6.
{
  pkgs,
  lib,
  ...
}: {
  # Runtime
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    dockerCompat = true;
    defaultNetwork.settings = {
      # Required for container networking to be able to use names.
      dns_enabled = true;
    };
  };
  virtualisation.oci-containers.backend = "podman";

  # Containers
  virtualisation.oci-containers.containers."bds-bds" = {
    image = "itzg/minecraft-bedrock-server";
    environment = {
      DIFFICULTY = "normal";
      EULA = "TRUE";
      GAMEMODE = "survival";
      TICK_DISTANCE = "8";
    };
    volumes = [
      "/mnt/docker_volumes/bds:/data:rw"
    ];
    ports = [
      "19132:19132/udp"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=bds"
      "--network=bds-default"
    ];
  };
  systemd.services."podman-bds-bds" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "no";
    };
    after = [
      "podman-network-bds-default.service"
    ];
    requires = [
      "podman-network-bds-default.service"
    ];
    partOf = [
      "podman-compose-bds-root.target"
    ];
    wantedBy = [
      "podman-compose-bds-root.target"
    ];
  };

  # Networks
  systemd.services."podman-network-bds-default" = {
    path = [pkgs.podman];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "${pkgs.podman}/bin/podman network rm -f bds-default";
    };
    script = ''
      podman network inspect bds-default || podman network create bds-default --opt isolate=true
    '';
    partOf = ["podman-compose-bds-root.target"];
    wantedBy = ["podman-compose-bds-root.target"];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-bds-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = ["multi-user.target"];
  };
}
