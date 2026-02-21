# Clubcotton site instance definitions
# Controller host: nix-01 (can failover to nix-02/03)
{
  # Home Assistant OS VM
  # Image must be pre-imported: cd terraform/images/haos && ./run.sh --import
  prod-homeassistant = {
    type = "vm";
    deploy = "opaque";
    profile = "haos";
    imageAlias = "haos";
    storagePool = "local";
    network = {
      mode = "bridged";
      parent = "br0";
      hwaddr = "00:16:3e:3d:95:f2";
    };
    extraConfig = {
      "migration.stateful" = "false";
      "boot.autostart" = "true";
    };
  };

  # FreshRSS - RSS feed aggregator
  # First NixOS container on the cluster (Phase 1.5)
  # Dependencies: PostgreSQL on nas-01 (network), agenix secrets
  freshrss = {
    type = "container";
    deploy = "image";
    configuration = "freshrss";
    profile = "small";
    storagePool = "local";
    target = "nix-01";
    network = {
      mode = "bridged";
      parent = "br0";
    };
  };
}
