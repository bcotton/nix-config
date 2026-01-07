{
  description = "Playwright testing environment for CI/automation";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {nixpkgs, ...}: let
    # Linux-only: playwright-driver.browsers not available on Darwin
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        nodejs_22
        playwright-driver.browsers
      ];

      shellHook = ''
        export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
        export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true

        echo "Playwright environment ready"
        echo "  Browser path: $PLAYWRIGHT_BROWSERS_PATH"
        echo "  Required npm version: @playwright/test@1.52.0"
      '';
    };
  };
}
