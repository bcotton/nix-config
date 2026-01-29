{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: {
  users.users.larry =
    {
      shell = pkgs.zsh;
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux {
      # NixOS-specific options
      isNormalUser = true;
      extraGroups = ["docker" "share" "llm-users"];
      linger = true; # Enable user services without active login session
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJLuhL6Z0u8AxfjSJoN4qLj8pFQvz6RaC2yAJ4xuGWam larry@nix-02"
      ];
    };
}
