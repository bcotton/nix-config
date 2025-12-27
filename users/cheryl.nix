{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: {
  users.users.cheryl =
    {
      shell = pkgs.zsh;
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux {
      # NixOS-specific options
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPSbpQ7NNYBQnmw4rOIhqjaLFWPVJANdoaNxMM73cSmE cheryl@nas-01"
      ];
    };
}
