{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs,
  chromium,
}:
buildNpmPackage rec {
  pname = "playwright-cli";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "playwright-cli";
    rev = "v${version}";
    hash = "sha256-9LuLQ2klYz91rEkxNDwcx0lYgE6GPoTJkwgxI/4EHgg=";
  };

  npmDepsHash = "sha256-DvorQ40CCNQJNQdTPFyMBErFNicSWkNT/e6S8cfZlRA=";

  # Prevent playwright from downloading browsers during build
  env.PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";

  # No compilation needed - ships as pre-written JS
  dontNpmBuild = true;

  nativeBuildInputs = [makeWrapper];

  postInstall = ''
    # Playwright hardcodes /opt/google/chrome/chrome for its chrome channel.
    # Patch it to use nixpkgs chromium instead.
    substituteInPlace $out/lib/node_modules/@playwright/cli/node_modules/playwright-core/lib/server/registry/index.js \
      --replace-quiet '/opt/google/chrome/chrome' '${chromium}/bin/chromium'

    wrapProgram $out/bin/playwright-cli \
      --set PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS "true" \
      --set PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD "1"
  '';

  meta = {
    description = "Token-efficient CLI for browser automation, designed for AI coding agents";
    homepage = "https://github.com/microsoft/playwright-cli";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "playwright-cli";
  };
}
