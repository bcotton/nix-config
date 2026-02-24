{
  config,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    v4l-utils
    ustreamer
  ];
  services.octoprint = {
    enable = true;
    # see here for more plugins https://github.com/BBBSnowball/nixcfg/blob/4f807f1eb702e3996d81a6b32ec3ace98fcf72df/hosts/gk3v-pb/3dprint.nix#L6
    plugins = plugins:
      with plugins; [
        bedlevelvisualizer
        themeify
        # octolapse
      ];
  };

  # Webcam streaming via ustreamer (replaces broken mjpg-streamer)
  systemd.services.ustreamer = {
    description = "ustreamer webcam streamer";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = "${pkgs.ustreamer}/bin/ustreamer --device /dev/video0 --resolution 1280x720 --host 0.0.0.0 --port 5050";
      DynamicUser = true;
      SupplementaryGroups = ["video"];
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  networking.firewall.allowedTCPPorts = [5000 5050];

  # don't abort a running print, please
  # (NixOS will tell us when a restart is necessary and we can do it at a time of our choosing.)
  systemd.services.octoprint.restartIfChanged = false;
}
