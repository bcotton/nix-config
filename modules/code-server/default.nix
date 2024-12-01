{
  config,
  pkgs,
  ...
}: {
  services.code-server = {
    enable = true;
    auth = "none"; # Protected by Tailscale
    disableTelemetry = true;
    disableUpdateCheck = true;
    disableWorkspaceTrust = true;
    disableGettingStartedOverride = true;
    host = "0.0.0.0";

    user = "bcotton";
    extraPackages = with pkgs; [
      nil
    ];
  };
}
