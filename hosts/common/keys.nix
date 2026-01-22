{
  # Centralized SSH public keys for the nix-config fleet
  # Import this file in host configurations to use these keys

  # User SSH keys - can be combined for root access on shared hosts
  users = {
    bcotton = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA51nSUvq7WevwvTYzD1S2xSr9QU7DVuYu3k/BGZ7vJ0 bob.cotton@gmail.com";
    tcotton-mbp = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKW08oClThlF1YJ+ey3y8XKm9yX/45EtaM/W7hx5Yvzb tomcotton@Toms-MacBook-Pro.local";
    tcotton-lan = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEbIFTdml6HkOUMHN7krdP3eIYSPQN6oOGKVu8aA8IVW tomcotton@Toms-MBP.lan";
  };

  # Default root authorized keys (bcotton has access to all hosts)
  rootAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA51nSUvq7WevwvTYzD1S2xSr9QU7DVuYu3k/BGZ7vJ0 bob.cotton@gmail.com"
  ];

  # SSH keys for nix remote builder user
  builderAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDqGI8tMC4OzuZB8mmYnPSQgIgZaDUglqdIqS9U4H5fT nix-builder@nas-01"
  ];
}
