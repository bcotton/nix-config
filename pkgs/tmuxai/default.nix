{
  lib,
  buildGoModule,
  fetchFromGitHub,
  tmux,
}:
buildGoModule rec {
  pname = "tmuxai";
  version = "unstable-2024-04-30"; # Using unstable since it's in active development

  src = fetchFromGitHub {
    owner = "alvinunreal";
    repo = "tmuxai";
    rev = "0f5d35eb1808279ba9c5e0c05c2743d989e2c4a1";
    sha256 = "sha256-80m6iHuArazKL6kc/qRV3PCphycefjwWvyzK0m7vXVk=";
  };

  vendorHash = "sha256-mgWud7Ic6SjiCsKnEbyzd5NZbyq8Cx1c5VIddYyCsfI=";

  ldflags = [
    "-s"
    "-w"
    "-extldflags '-static'"
  ];

  # Ensure tmux is available at runtime
  runtimeDependencies = [tmux];

  meta = with lib; {
    description = "AI-Powered, Non-Intrusive Terminal Assistant";
    homepage = "https://github.com/alvinunreal/tmuxai";
    license = licenses.asl20; # Apache-2.0
    maintainers = with maintainers; [];
    mainProgram = "tmuxai";
    platforms = platforms.unix;
  };
}
