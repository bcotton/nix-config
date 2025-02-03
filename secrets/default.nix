{
  config,
  lib,
  ...
}: {
  
  # Generate postgres secrets here: https://supercaracal.github.io/scram-sha-256/

  # Unconditional secrets (no special permissions needed)
  age.secrets."tailscale-keys.env" = {
    file = ./tailscale-keys.env;
  };
  age.secrets."tailscale-keys" = {
    file = ./tailscale-keys.raw;
  };
  age.secrets."grafana-cloud" = {
    file = ./grafana-cloud.age;
  };
  age.secrets."open-webui" = lib.mkIf config.services.clubcotton.open-webui.enable {
    file = ./open-webui.age;
  };
  age.secrets."mqtt" = {
    file = ./mqtt.age;
  };
  age.secrets."wireless-config" = {
    file = ./wireless-config.age;
  };

  # Conditional secrets based on services
  age.secrets."pushover-key" = lib.mkIf config.services.prometheus.alertmanager.enable {
    file = ./pushover-key.age;
    owner = "alertmanager";
    group = "alertmanager";
  };

  age.secrets."pushover-token" = lib.mkIf config.services.prometheus.alertmanager.enable {
    file = ./pushover-token.age;
    owner = "alertmanager";
    group = "alertmanager";
  };

  age.secrets."condo-ha-token" = lib.mkIf config.services.prometheus.enable {
    file = ./condo-ha-token.age;
    owner = "prometheus";
    group = "prometheus";
  };

  age.secrets."homeassistant-token" = lib.mkIf config.services.prometheus.enable {
    file = ./homeassistant-token.age;
    owner = "prometheus";
    group = "prometheus";
  };

  age.secrets."unpoller" = lib.mkIf config.services.unpoller.enable {
    file = ./unpoller.age;
    owner = "unifi-poller";
    group = "unifi-poller";
  };

  # Make sure this secretfile is specifying both LIBRESPOT_USERNAME and LIBRESPOT_PASSWORD
  age.secrets.librespot = lib.mkIf config.services.snapserver.enable {
    file = ./librespot.age;
  };

  age.secrets.mopidy = lib.mkIf config.services.mopidy.enable {
    file = ./mopidy.age;
    # owner = "mopidy";
    # group = "mopidy";
  };

  age.secrets."immich-database" = lib.mkIf config.services.clubcotton.postgresql.enable {
    file = ./immich-database.age;
    owner = "postgres";
    group = "postgres";
  };

  age.secrets."immich" = lib.mkIf config.services.clubcotton.immich.enable {
    file = ./immich.age;
    owner = "immich";
    group = "immich";
  };

  age.secrets."open-webui-database" = lib.mkIf config.services.clubcotton.postgresql.open-webui.enable {
    file = ./open-webui-database.age;
    owner = "postgres";
    group = "postgres";
  };

  age.secrets."atuin-database" = lib.mkIf config.services.clubcotton.postgresql.atuin.enable {
    file = ./atuin-database.age;
    owner = "postgres";
    group = "postgres";
  };
  age.secrets."atuin" = lib.mkIf config.services.clubcotton.atuin.enable {
    file = ./atuin.age;
    owner = "atuin";
    group = "atuin";
  };

  age.secrets."webdav" = lib.mkIf config.services.clubcotton.webdav.enable {
    file = ./webdav.age;
    owner = "webdav";
    group = "share";
  };

  age.secrets."kavita-token" = lib.mkIf config.services.clubcotton.kavita.enable {
    file = ./kavita-token.age;
  };

  age.secrets."navidrome" = lib.mkIf config.services.clubcotton.navidrome.enable {
    file = ./navidrome.age;
  };
}
