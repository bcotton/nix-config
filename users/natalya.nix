{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: {
  users.users.natalya =
    {
      shell = pkgs.zsh;
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux {
      # NixOS-specific options
      isNormalUser = true;
      uid = 1004; # Explicit UID for container bind mounts
      extraGroups = ["docker" "share"];
      linger = true; # Enable user services without active login session
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBDSG897SmzTyBDbGroPjbN8FBG191n4lSE2j7GWkmU7 natalya@nix-01"
      ];
    };
}
