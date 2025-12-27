{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: {
  users.users.tomcotton =
    {
      shell = pkgs.zsh;
      packages = with pkgs; [
        tree
        tmux
        git
        firefox
      ];
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux {
      # NixOS-specific options
      isNormalUser = true;
      extraGroups = ["wheel" "docker" "podman" "share"]; # Enable 'sudo' for the user.
      hashedPassword = "$6$wpaUixsrLhBdbijm$Wi4KRo2smEcnDOb8vXpxSZJWPUBZyDdWQEtYkjDtqMBr25nFfNpk3IjBr816x/FdAxU7YlinKs5lKmJi3huNp0";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKW08oClThlF1YJ+ey3y8XKm9yX/45EtaM/W7hx5Yvzb tomcotton@Toms-MacBook-Pro.local"
      ];
    };
}
