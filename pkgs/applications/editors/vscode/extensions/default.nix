{ lib, pkgs }:

let
  inherit (lib) maintainers;
  inherit (pkgs.vscode-utils) buildVscodeMarketplaceExtension;
in
{
  cline = buildVscodeMarketplaceExtension {
    mktplcRef = {
      name = "claude-dev";
      publisher = "saoudrizwan";
      version = "3.1.5";
      sha256 = "sha256-jfWJVyBftEYymJdlr+MlrdXwpdmTtIEf1kiv7LPj7JA=";
    };
    meta = with lib; {
      description = "Autonomous coding agent right in your IDE, capable of creating/editing files, executing commands, using the browser, and more with your permission every step of the way";
      homepage = "https://github.com/cline/cline";
      license = licenses.asl20;
      maintainers = [ maintainers.bcotton ];
    };
  };
}
