# Auto-generated using compose2nix v0.2.0-pre.
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
  virtualisation.oci-containers.containers."immich-tailscale" = {
    image = "tailscale/tailscale:latest";
    environment = {
      TS_STATE_DIR = "/var/lib/tailscale";
    };
    environmentFiles = [
      "/run/agenix/tailscale-keys.env"
    ];

    volumes = [
      "/dev/net/tun:/dev/net/tun:rw"
      "/mnt/docker_volumes/tailscale/immich:/var/lib/tailscale:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--cap-add=net_admin"
      "--cap-add=sys_module"
      "--hostname=photos"
      "--network-alias=tailscale"
      "--network=immich_default"
    ];
  };
  systemd.services."podman-immich-tailscale" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
    };
    after = [
      "podman-network-immich_default.service"
    ];
    requires = [
      "podman-network-immich_default.service"
    ];
    partOf = [
      "podman-compose-immich-root.target"
    ];
    wantedBy = [
      "podman-compose-immich-root.target"
    ];
  };
  virtualisation.oci-containers.containers."immich_machine_learning" = {
    image = "ghcr.io/immich-app/immich-machine-learning:v1.121.0";
    environment = {
      DB_DATABASE_NAME = "immich";
      DB_DATA_LOCATION = "/mnt/docker_volumes/immich/immich_pgdata";
      DB_HOSTNAME = "immich_postgres";
      DB_PASSWORD = "postgres";
      DB_USERNAME = "postgres";
      IMMICH_VERSION = "v1.121.0";
      REDIS_HOSTNAME = "immich_redis";
      TYPESENSE_API_KEY = "some-random-text";
      UPLOAD_LOCATION = "/mnt/docker_volumes/immich/immich-data/upload";
    };
    volumes = [
      "/mnt/docker_volumes/immich/immich_model-cache:/cache:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=immich-machine-learning"
      "--network=immich_default"
    ];
  };
  systemd.services."podman-immich_machine_learning" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
    };
    after = [
      "podman-network-immich_default.service"
    ];
    requires = [
      "podman-network-immich_default.service"
    ];
    partOf = [
      "podman-compose-immich-root.target"
    ];
    wantedBy = [
      "podman-compose-immich-root.target"
    ];
  };
  virtualisation.oci-containers.containers."immich_postgres" = {
    image = "tensorchord/pgvecto-rs:pg14-v0.2.0@sha256:90724186f0a3517cf6914295b5ab410db9ce23190a2d9d0b9dd6463e3fa298f0";
    environment = {
      DB_DATABASE_NAME = "immich";
      DB_DATA_LOCATION = "/mnt/docker_volumes/immich/immich_pgdata";
      DB_HOSTNAME = "immich_postgres";
      DB_PASSWORD = "postgres";
      DB_USERNAME = "postgres";
      IMMICH_VERSION = "v1.121.0";
      POSTGRES_DB = "immich";
      POSTGRES_PASSWORD = "postgres";
      POSTGRES_USER = "postgres";
      REDIS_HOSTNAME = "immich_redis";
      TYPESENSE_API_KEY = "some-random-text";
      UPLOAD_LOCATION = "/mnt/docker_volumes/immich/immich-data/upload";
    };
    volumes = [
      "/mnt/docker_volumes/immich/immich_pgdata:/var/lib/postgresql/data:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=database"
      "--network=immich_default"
    ];
  };
  systemd.services."podman-immich_postgres" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
    };
    after = [
      "podman-network-immich_default.service"
    ];
    requires = [
      "podman-network-immich_default.service"
    ];
    partOf = [
      "podman-compose-immich-root.target"
    ];
    wantedBy = [
      "podman-compose-immich-root.target"
    ];
  };
  virtualisation.oci-containers.containers."immich_redis" = {
    image = "redis:6.2-alpine@sha256:c5a607fb6e1bb15d32bbcf14db22787d19e428d59e31a5da67511b49bb0f1ccc";
    log-driver = "journald";
    extraOptions = [
      "--network-alias=redis"
      "--network=immich_default"
    ];
  };
  systemd.services."podman-immich_redis" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
    };
    after = [
      "podman-network-immich_default.service"
    ];
    requires = [
      "podman-network-immich_default.service"
    ];
    partOf = [
      "podman-compose-immich-root.target"
    ];
    wantedBy = [
      "podman-compose-immich-root.target"
    ];
  };
  virtualisation.oci-containers.containers."immich_server" = {
    image = "ghcr.io/immich-app/immich-server:v1.121.0";
    environment = {
      DB_DATABASE_NAME = "immich";
      DB_DATA_LOCATION = "/mnt/docker_volumes/immich/immich_pgdata";
      DB_HOSTNAME = "immich_postgres";
      DB_PASSWORD = "postgres";
      DB_USERNAME = "postgres";
      IMMICH_VERSION = "v1.121.0";
      IMMICH_PORT = "80";
      REDIS_HOSTNAME = "immich_redis";
      TYPESENSE_API_KEY = "some-random-text";
      UPLOAD_LOCATION = "/mnt/docker_volumes/immich/immich-data/upload";
    };
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "/mnt/docker_volumes/immich/immich-data/upload:/usr/src/app/upload:rw"
    ];
    ports = [
      "2283:2283/tcp"
    ];
    dependsOn = [
      "immich-tailscale"
      "immich_postgres"
      "immich_redis"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network=container:immich-tailscale"
    ];
  };
  systemd.services."podman-immich_server" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
    };
    partOf = [
      "podman-compose-immich-root.target"
    ];
    wantedBy = [
      "podman-compose-immich-root.target"
    ];
  };

  # Networks
  systemd.services."podman-network-immich_default" = {
    path = [pkgs.podman];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "${pkgs.podman}/bin/podman network rm -f immich_default";
    };
    script = ''
      podman network inspect immich_default || podman network create immich_default
    '';
    partOf = ["podman-compose-immich-root.target"];
    wantedBy = ["podman-compose-immich-root.target"];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-immich-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = ["multi-user.target"];
  };
}
