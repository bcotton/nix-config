{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    formatter = pkgs.alejandra;
  };
}
