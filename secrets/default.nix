{
  config,
  lib,
  ...
}: {
  # Generate postgres secrets here: https://supercaracal.github.io/scram-sha-256/

  # Unconditional secrets (no special permissions needed)
  age.secrets."tailscale-keys.env" = lib.mkIf config.services.tailscale.enable {
    file = ./tailscale-keys.env;
  };
  age.secrets."tailscale-keys" = lib.mkIf config.services.tailscale.enable {
    file = ./tailscale-keys.raw;
  };
  age.secrets."grafana-cloud" = lib.mkIf config.services.alloy.enable {
    file = ./grafana-cloud.age;
  };
  age.secrets."open-webui" = lib.mkIf config.services.clubcotton.open-webui.enable {
    file = ./open-webui.age;
  };
  age.secrets."mqtt" = lib.mkIf config.services.frigate.enable {
    file = ./mqtt.age;
  };
  age.secrets."wireless-config" = lib.mkIf config.networking.wireless.enable {
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

  age.secrets."forgejo-database" = lib.mkIf config.services.clubcotton.postgresql.forgejo.enable {
    file = ./forgejo-database.age;
    owner = "postgres";
    group = "postgres";
  };

  age.secrets."forgejo-db-password" = lib.mkIf config.services.clubcotton.forgejo.enable {
    file = ./forgejo-db-password.age;
    owner = "forgejo";
    group = "forgejo";
  };

  age.secrets."forgejo-runner-token" = lib.mkIf config.services.clubcotton.forgejo-runner.enable {
    file = ./forgejo-runner-token.age;
    owner = "gitea-runner";
    group = "gitea-runner";
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

  age.secrets."tfstate-database" = lib.mkIf config.services.clubcotton.postgresql.tfstate.enable {
    file = ./tfstate-database.age;
    owner = "postgres";
    group = "postgres";
  };

  age.secrets."tfstate-database-raw" = lib.mkIf config.services.clubcotton.postgresql.tfstate.enable {
    file = ./tfstate-database-raw.age;
    owner = "bcotton";
    group = "users";
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

  age.secrets."paperless" = lib.mkIf config.services.clubcotton.paperless.enable {
    file = ./paperless.age;
    owner = "paperless";
    group = "paperless";
  };

  age.secrets."paperless-database" = lib.mkIf config.services.clubcotton.postgresql.paperless.enable {
    file = ./paperless-database.age;
    owner = "postgres";
    group = "postgres";
  };

  age.secrets."paperless-database-raw" = lib.mkIf config.services.clubcotton.paperless.enable {
    file = ./paperless-database-raw.age;
    owner = "paperless";
    group = "paperless";
  };

  # Atuin client key - needed on all machines where bcotton uses atuin
  # (not just where the atuin server runs)
  age.secrets."bcotton-atuin-key" = lib.mkIf (config.users.users ? bcotton) {
    file = ./bcotton-atuin-key.age;
    owner = "bcotton";
    group = "users";
  };

  age.secrets."navidrome" = lib.mkIf config.services.clubcotton.navidrome.enable {
    file = ./navidrome.age;
  };

  age.secrets."freshrss" = lib.mkIf config.services.clubcotton.freshrss.enable {
    file = ./freshrss.age;
    owner = "freshrss";
    group = "freshrss";
  };

  age.secrets."freshrss-database" = lib.mkIf config.services.clubcotton.postgresql.freshrss.enable {
    file = ./freshrss-database.age;
    owner = "postgres";
    group = "postgres";
  };

  age.secrets."freshrss-database-raw" = lib.mkIf config.services.clubcotton.freshrss.enable {
    file = ./freshrss-database-raw.age;
    owner = "freshrss";
    group = "freshrss";
  };

  age.secrets."nut-client-password" = lib.mkIf (config.services.clubcotton."nut-server".enable
    || config.services.clubcotton."nut-client".enable) {
    file = ./nut-client.age;
  };

  age.secrets."scanner-user-private-ssh-key" = lib.mkIf config.services.clubcotton.scanner.enable {
    file = ./scanner-user-private-ssh-key.age;
    owner = "scanner";
    group = "users";
  };

  age.secrets."wallabag" = lib.mkIf config.services.clubcotton.wallabag.enable {
    file = ./wallabag.age;
    owner = "wallabag";
    group = "wallabag";
  };

  age.secrets."syncoid-ssh-key" = lib.mkIf (config.services.clubcotton.syncoid.enable || config.services.clubcotton.borgmatic.enable) {
    file = ./syncoid-ssh-key.age;
    owner =
      if config.services.clubcotton.borgmatic.enable
      then "root"
      else "syncoid";
    group =
      if config.services.clubcotton.borgmatic.enable
      then "root"
      else "syncoid";
    mode = "0400";
  };

  age.secrets."borg-passphrase" = lib.mkIf config.services.clubcotton.borgmatic.enable {
    file = ./borg-passphrase.age;
    owner = "root";
    group = "root";
  };

  # Harmonia binary cache signing key
  age.secrets."harmonia-signing-key" = lib.mkIf config.services.clubcotton.harmonia.enable {
    file = ./harmonia-signing-key.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  # Nix builder SSH keys
  age.secrets."nix-builder-ssh-key" = lib.mkIf (config.services.nix-builder.coordinator.enable or false) {
    file = ./nix-builder-ssh-key.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  age.secrets."nix-builder-ssh-pub" = lib.mkIf ((config.services.nix-builder.coordinator.enable or false) || (config.users.users ? nix-builder)) {
    file = ./nix-builder-ssh-pub.age;
    owner = "root";
    group = "root";
    mode = "0444";
  };
}
