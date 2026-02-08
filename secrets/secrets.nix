# to add or edit the secrets run 'agenix -e <file>.age'
# to add a file, add it to the list below, then run 'agenix -e <file>.age'
let
  bcotton = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA51nSUvq7WevwvTYzD1S2xSr9QU7DVuYu3k/BGZ7vJ0 bob.cotton@gmail.com";
  tomcotton = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKW08oClThlF1YJ+ey3y8XKm9yX/45EtaM/W7hx5Yvzb tomcotton@Toms-MacBook-Pro.local";
  larry = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJLuhL6Z0u8AxfjSJoN4qLj8pFQvz6RaC2yAJ4xuGWam larry@nix-02";
  users = [bcotton tomcotton];
  anthropic_users = [bcotton tomcotton larry];
  just_bob = [bcotton];
  just_larry = [larry bcotton];

  # Bot host system keys (for decrypting bot secrets at boot)
  botSystems = [nix-01 nix-02 nix-03];

  admin = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMjeiDeFxI7BcbjDxtPyeWfsUWBW2HKTyjT8/X0719+p root@nixos";
  condo-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINIpIbNwuXjaydV3NuE7+sb+jnSM3jsCb/+lCV+X6MYX root@nix-04";
  natalya-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILDfCGE+HnYYetqjAC+WWG+LorlsSVQQ1szJGn0webg2 root@natalya-01";
  dns-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBD6tjNNrFlFu0PqKg3bQc2BiUJpsqVVv3nESGno4ahn root@dns-01";
  imac-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAKs1khAuSbZNVI31+oO2IwO/9Q2p6AAfylhAJP9DpW2 root@imac-01";
  imac-02 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDytO1fpZ+i2QPXjg+XuNYLVjLJv6c0snq2OO5q6rxN0 root@imac-02";
  nix-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJDEJMkba6F8w5b1nDZ3meKEb7PNcWbErBtofbejrIh+ root@nix-01";
  nix-02 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFP84qqvaOkowcYY3B1b96AJ3TPBo0EOlIJuqYQF/AfM root@nix-02";
  nix-03 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEQtcczbSCjUK0NH1M6fTIG21Ta5XcvygsFimfNDMqXz root@nix-03";
  nas-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK4/K8BbFVT/V5SRlWwjBb2vowBQjCiReOeNRw+C+/c4 root@nas-01";
  octoprint = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKtxU4yWKvKtZUV82nISi21UCnZ8D2ua8mPMkhk1flNH root@octoprint";
  frigate-host = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL7E24JIWthIHIyTnqjdmJPeGUw8UreinxDNfVq9N2AP root@frigate-host";
  nixbook-test = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDTtjWF4ZxB9xIcJeOPpGE7swaikFG52fSJQmIz4sQuE root@toms-laptop-01";
  nixos-utm = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFtSuZJ1o7vdfKiooH8AlKnUkyBx6eBqQl+XZ3SdkRyQ root@nixos";

  systems = [admin condo-01 natalya-01 dns-01 imac-01 imac-02 nix-01 nix-02 nix-03 nas-01 octoprint frigate-host nixbook-test nixos-utm];
in {
  "atuin.age".publicKeys = users ++ systems;
  "atuin-database.age".publicKeys = users ++ systems;
  "anthropic-api-key.age".publicKeys = anthropic_users ++ botSystems;
  "bcotton-atuin-key.age".publicKeys = users ++ systems;
  "borg-passphrase.age".publicKeys = users ++ systems;
  "restic-password.age".publicKeys = users ++ systems;
  "restic-b2-env.age".publicKeys = users ++ systems;
  "cloudflare-tunnel-token.age".publicKeys = users ++ systems;
  "condo-ha-token.age".publicKeys = users ++ systems;
  "freshrss.age".publicKeys = users ++ systems;
  "freshrss-database.age".publicKeys = users ++ systems;
  "freshrss-database-raw.age".publicKeys = users ++ systems;
  "forgejo-db-password.age".publicKeys = users ++ systems;
  "forgejo-database.age".publicKeys = users ++ systems;
  "forgejo-runner-token.age".publicKeys = users ++ systems;
  "garage-rpc-secret.age".publicKeys = users ++ systems;
  # Uncomment after creating: agenix -e garage-metrics-token.age
  # "garage-metrics-token.age".publicKeys = users ++ systems;
  "grafana-cloud.age".publicKeys = users ++ systems;
  "harmonia-signing-key.age".publicKeys = users ++ systems;
  "homeassistant-token.age".publicKeys = users ++ systems;
  "immich-database.age".publicKeys = users ++ systems;
  "immich.age".publicKeys = users ++ systems;
  "kavita-token.age".publicKeys = users ++ systems;
  "librespot.age".publicKeys = users ++ systems;
  "mopidy.age".publicKeys = users ++ systems;
  "mqtt.age".publicKeys = users ++ systems;
  "navidrome.age".publicKeys = users ++ systems;
  "nix-builder-ssh-key.age".publicKeys = users ++ systems;
  "nix-builder-ssh-pub.age".publicKeys = users ++ systems;
  "nut-client.age".publicKeys = users ++ systems;
  "obsidian-bcotton.age".publicKeys = users ++ systems; # Uncomment after creating with: agenix -e obsidian-bcotton.age
  "obsidian-natalya.age".publicKeys = users ++ systems;
  "open-webui-database.age".publicKeys = users ++ systems;
  "open-webui.age".publicKeys = users ++ systems;
  "paperless.age".publicKeys = users ++ systems;
  "paperless-database.age".publicKeys = users ++ systems;
  "paperless-database-raw.age".publicKeys = users ++ systems;
  "pushover-key.age".publicKeys = users ++ systems;
  "pushover-token.age".publicKeys = users ++ systems;
  "scanner-user-private-ssh-key.age".publicKeys = users ++ systems;
  "syncoid-ssh-key.age".publicKeys = users ++ systems;
  "tailscale-keys.env".publicKeys = users ++ systems;
  "tailscale-keys.raw".publicKeys = users ++ systems;
  "technitium-admin-password.age".publicKeys = users ++ systems;
  "technitium-cluster-secret.age".publicKeys = users ++ systems;
  "tfstate-database.age".publicKeys = users ++ systems;
  "tfstate-database-raw.age".publicKeys = users ++ systems;
  "unpoller.age".publicKeys = users ++ systems;
  "wallabag.age".publicKeys = users ++ systems;
  "webdav.age".publicKeys = users ++ systems;
  "wireless-config.age".publicKeys = users ++ systems;

  # LLM API keys (shared by llm-users, decryptable on bot hosts)
  "openai-api-key.age".publicKeys = anthropic_users ++ botSystems;
  "openrouter-api-key.age".publicKeys = anthropic_users ++ botSystems;

  # Bot secrets (larry + bot host systems for decryption)
  "forgejo-password-larry.age".publicKeys = just_larry ++ botSystems;
  "forgejo-token-larry.age".publicKeys = just_larry ++ botSystems;
  "moltbot-telegram-token.age".publicKeys = just_larry ++ botSystems;
  "moltbot-gateway-token.age".publicKeys = just_larry ++ botSystems;
}
