{
  config,
  pkgs,
  unstablePkgs,
  lib,
  ...
}: let
  libedgetpu = pkgs.callPackage ../../pkgs/libedgetpu {};
  setApexPermissionsScript = pkgs.writeShellScript "set-apex-permissions" ''
    chown frigate:frigate /dev/apex_0
    chmod 660 /dev/apex_0
  '';
in {
  services.go2rtc = {
    enable = true;
    settings.streams = config.services.frigate.settings.go2rtc.streams;
  };

  services.frigate = {
    enable = true;
    hostname = "frigate";

    settings = {
      detectors = {
        coral = {
          type = "edgetpu";
          device = "pci";
        };
      };

      ffmpeg = {
        hwaccel_args = "preset-vaapi";
        # hwaccel_args = "-vaapi_device /dev/dri/renderD128 -hwaccel_output_format qsv -c:v h264_qsv";
      };

      mqtt = {
        enabled = true;
        host = "192.168.20.20";
        user = "{FRIGATE_MQTT_USER}";
        password = "{FRIGATE_MQTT_PASSWORD}";
      };

      record = {
        enabled = true;
        retain = {
          days = 2;
          mode = "all";
        };
      };

      birdseye = {
        enabled = true;
        mode = "continuous";
      };

      objects = {
        filters.person.threshold = "0.8";
      };

      cameras = {
        frontporch = {
          ffmpeg.inputs = [
            {
              path = "rtsp://127.0.0.1:8554/frontporch?video=copy&audio=aac";
              roles = ["record" "detect"];
            }
          ];
          snapshots = {
            enabled = true;
            required_zones = ["zone_0"];
          };
          record = {
            enabled = true;
            retain.days = 2;
            events.retain.default = 5;
            events.required_zones = ["zone_0"];
          };
          zones = {
            zone_0 = {
              coordinates = "0,1080,1920,1080,1899,256,0,239";
            };
          };
        };

        backporch = {
          ffmpeg.inputs = [
            {
              path = "rtsp://127.0.0.1:8554/backporch?video=copy&audio=aac";
              roles = ["record" "detect"];
            }
          ];
        };
        northside = {
          ffmpeg.inputs = [
            {
              path = "rtsp://127.0.0.1:8554/northside?video=copy&audio=aac";
              roles = ["record" "detect"];
            }
          ];
          snapshots = {
            enabled = true;
            required_zones = ["zone_0"];
          };
          record = {
            enabled = true;
            retain.days = 2;
            events.retain.default = 5;
            events.required_zones = ["zone_0"];
          };
          zones = {
            zone_0 = {
              coordinates = "411,1549,1754,1855,1717,561,716,524,0,1212";
            };
          };
        };
      };

      go2rtc = {
        log = {
          format = "text";
          exec = "trace";
        };

        streams.backporch = [
          "rtsp://192.168.20.194:8554/1080p?mp4"
          "ffmpeg:backporch#video=h264#hardware"
        ];

        streams.frontporch = [
          "rtsp://192.168.20.140:8554/1080p?mp4"
          "ffmpeg:frontporch#video=h264#hardware"
        ];

        streams.northside = [
          "rtmp://192.168.20.129/bcs/channel0_main.bcs?channel=0&stream=0&user=\${FRIGATE_CAMERA_USER}&password=\${FRIGATE_CAMERA_PASSWORD}"
          "ffmpeg:northside#video=h264#hardware"
        ];
      };
    };
  };

  systemd.services.frigate.environment.LD_LIBRARY_PATH = lib.makeLibraryPath [
    "${libedgetpu}"
    pkgs.libusb # libusb
  ];

  systemd.services.set-apex-permissions = {
    description = "Set permissions for /dev/apex_0";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${setApexPermissionsScript}";
    };
    wantedBy = ["multi-user.target"];
  };

  systemd.services.frigate = {
    serviceConfig = {
      EnvironmentFile = config.age.secrets.mqtt.path;
      AmbientCapabilities = "cap_perfmon";
      CapabilityBoundingSet = "cap_perfmon";
    };
    wants = ["set-apex-permissions.service"];
  };
  systemd.services.go2rtc.serviceConfig = {
    EnvironmentFile = config.age.secrets.mqtt.path;
  };
  # append to the render group in nixos
  users.users.frigate.extraGroups = ["render" "video"];
}
