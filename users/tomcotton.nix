{
  config,
  pkgs,
  unstablePkgs,
  ...
}: {
  users.users.tomcotton = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = ["wheel" "docker"]; # Enable ‘sudo’ for the user.
    hashedPassword = "$6$icZo8IyqPlu1YOgc$aRlFcb7dxOOmOebE/hYdLXWPEboyEm5sfBBJZopuRfD1Hu7MQYw0eQokQecb0n5HUgaGXRWMrs2TUqcZMIzC71";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKW08oClThlF1YJ+ey3y8XKm9yX/45EtaM/W7hx5Yvzb tomcotton@Toms-MacBook-Pro.local"
    ];
    packages = with pkgs; [
      tree
      tmux
      git
      firefox
    ];
  };
}
