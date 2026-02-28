{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.clubcotton.amdgpu-monitoring;

  metricsScript = pkgs.writeShellScript "amdgpu-metrics-collector" ''
    set -euo pipefail

    TEXTFILE_DIR="/var/lib/prometheus-node-exporter-text-files"
    PROM_FILE="$TEXTFILE_DIR/amdgpu.prom"
    TMP_FILE="$PROM_FILE.tmp"
    JQ="${pkgs.jq}/bin/jq"

    mkdir -p "$TEXTFILE_DIR"

    JSON=$(${pkgs.amdgpu_top}/bin/amdgpu_top --json -n 1 2>/dev/null || true)

    if [ -z "$JSON" ]; then
      : > "$TMP_FILE"
      chmod 644 "$TMP_FILE"
      mv "$TMP_FILE" "$PROM_FILE"
      exit 0
    fi

    # Extract metrics per device using jq
    # HELP/TYPE headers are emitted once; device loop emits only data points
    echo "$JSON" | $JQ -r '
      # Helper to extract labels per device
      def labels: (.Info.DeviceName // "unknown") as $name | (.Info.PCI // "unknown") as $pci | {$name, $pci};

      # Temperature
      "# HELP amdgpu_temperature_celsius GPU temperature in degrees Celsius.",
      "# TYPE amdgpu_temperature_celsius gauge",
      (.devices[] | labels as $l |
        (if .Sensors["Edge Temperature"].value then
          "amdgpu_temperature_celsius{device=\"\($l.pci)\",name=\"\($l.name)\",sensor=\"edge\"} \(.Sensors["Edge Temperature"].value)"
        else empty end),
        (if .Sensors["Junction Temperature"].value then
          "amdgpu_temperature_celsius{device=\"\($l.pci)\",name=\"\($l.name)\",sensor=\"junction\"} \(.Sensors["Junction Temperature"].value)"
        else empty end),
        (if .Sensors["Memory Temperature"].value then
          "amdgpu_temperature_celsius{device=\"\($l.pci)\",name=\"\($l.name)\",sensor=\"memory\"} \(.Sensors["Memory Temperature"].value)"
        else empty end)
      ),

      # Power
      "# HELP amdgpu_power_watts GPU power draw in watts.",
      "# TYPE amdgpu_power_watts gauge",
      (.devices[] | labels as $l |
        (if .Sensors["Average Power"].value then
          "amdgpu_power_watts{device=\"\($l.pci)\",name=\"\($l.name)\"} \(.Sensors["Average Power"].value)"
        else empty end)
      ),

      # Power cap
      "# HELP amdgpu_power_cap_watts GPU power cap in watts.",
      "# TYPE amdgpu_power_cap_watts gauge",
      (.devices[] | labels as $l |
        (if .Info["Power Cap"].current then
          "amdgpu_power_cap_watts{device=\"\($l.pci)\",name=\"\($l.name)\"} \(.Info["Power Cap"].current)"
        else empty end)
      ),

      # Fan speed
      "# HELP amdgpu_fan_rpm GPU fan speed in RPM.",
      "# TYPE amdgpu_fan_rpm gauge",
      (.devices[] | labels as $l |
        (if .Sensors.Fan.value then
          "amdgpu_fan_rpm{device=\"\($l.pci)\",name=\"\($l.name)\"} \(.Sensors.Fan.value)"
        else empty end)
      ),
      "# HELP amdgpu_fan_max_rpm GPU maximum fan speed in RPM.",
      "# TYPE amdgpu_fan_max_rpm gauge",
      (.devices[] | labels as $l |
        (if .Sensors["Fan Max"].value then
          "amdgpu_fan_max_rpm{device=\"\($l.pci)\",name=\"\($l.name)\"} \(.Sensors["Fan Max"].value)"
        else empty end)
      ),

      # Clock speeds
      "# HELP amdgpu_clock_mhz GPU clock speed in MHz.",
      "# TYPE amdgpu_clock_mhz gauge",
      (.devices[] | labels as $l |
        (if .Sensors.GFX_SCLK.value then
          "amdgpu_clock_mhz{device=\"\($l.pci)\",name=\"\($l.name)\",clock=\"gfx\"} \(.Sensors.GFX_SCLK.value)"
        else empty end),
        (if .Sensors.GFX_MCLK.value then
          "amdgpu_clock_mhz{device=\"\($l.pci)\",name=\"\($l.name)\",clock=\"mem\"} \(.Sensors.GFX_MCLK.value)"
        else empty end),
        (if .Sensors.FCLK.value then
          "amdgpu_clock_mhz{device=\"\($l.pci)\",name=\"\($l.name)\",clock=\"fabric\"} \(.Sensors.FCLK.value)"
        else empty end)
      ),

      # GPU activity
      "# HELP amdgpu_gpu_busy_percent GPU utilization percentage.",
      "# TYPE amdgpu_gpu_busy_percent gauge",
      (.devices[] | labels as $l |
        (if .gpu_activity.GFX.value != null then
          "amdgpu_gpu_busy_percent{device=\"\($l.pci)\",name=\"\($l.name)\",engine=\"gfx\"} \(.gpu_activity.GFX.value)"
        else empty end),
        (if .gpu_activity.Memory.value != null then
          "amdgpu_gpu_busy_percent{device=\"\($l.pci)\",name=\"\($l.name)\",engine=\"memory\"} \(.gpu_activity.Memory.value)"
        else empty end),
        (if .gpu_activity.MediaEngine.value != null then
          "amdgpu_gpu_busy_percent{device=\"\($l.pci)\",name=\"\($l.name)\",engine=\"media\"} \(.gpu_activity.MediaEngine.value)"
        else empty end)
      ),

      # VRAM usage
      "# HELP amdgpu_vram_bytes GPU VRAM in bytes.",
      "# TYPE amdgpu_vram_bytes gauge",
      (.devices[] | labels as $l |
        (if .VRAM["Total VRAM"].value then
          "amdgpu_vram_bytes{device=\"\($l.pci)\",name=\"\($l.name)\",type=\"total\"} \(.VRAM["Total VRAM"].value * 1048576)"
        else empty end),
        (if .VRAM["Total VRAM Usage"].value then
          "amdgpu_vram_bytes{device=\"\($l.pci)\",name=\"\($l.name)\",type=\"used\"} \(.VRAM["Total VRAM Usage"].value * 1048576)"
        else empty end),
        (if .VRAM["Total GTT"].value then
          "amdgpu_vram_bytes{device=\"\($l.pci)\",name=\"\($l.name)\",type=\"gtt_total\"} \(.VRAM["Total GTT"].value * 1048576)"
        else empty end),
        (if .VRAM["Total GTT Usage"].value then
          "amdgpu_vram_bytes{device=\"\($l.pci)\",name=\"\($l.name)\",type=\"gtt_used\"} \(.VRAM["Total GTT Usage"].value * 1048576)"
        else empty end)
      ),

      # Voltage
      "# HELP amdgpu_voltage_mv GPU voltage in millivolts.",
      "# TYPE amdgpu_voltage_mv gauge",
      (.devices[] | labels as $l |
        (if .Sensors.VDDGFX.value then
          "amdgpu_voltage_mv{device=\"\($l.pci)\",name=\"\($l.name)\",rail=\"gfx\"} \(.Sensors.VDDGFX.value)"
        else empty end)
      ),

      # PCIe link
      "# HELP amdgpu_pcie_link_speed_gen Current PCIe link generation.",
      "# TYPE amdgpu_pcie_link_speed_gen gauge",
      (.devices[] | labels as $l |
        (if .Sensors["PCIe Link Speed"].gen then
          "amdgpu_pcie_link_speed_gen{device=\"\($l.pci)\",name=\"\($l.name)\"} \(.Sensors["PCIe Link Speed"].gen)"
        else empty end)
      ),
      "# HELP amdgpu_pcie_link_width Current PCIe link width.",
      "# TYPE amdgpu_pcie_link_width gauge",
      (.devices[] | labels as $l |
        (if .Sensors["PCIe Link Speed"].width then
          "amdgpu_pcie_link_width{device=\"\($l.pci)\",name=\"\($l.name)\"} \(.Sensors["PCIe Link Speed"].width)"
        else empty end)
      )
    ' > "$TMP_FILE"

    chmod 644 "$TMP_FILE"
    mv "$TMP_FILE" "$PROM_FILE"
  '';
in {
  options.clubcotton.amdgpu-monitoring = {
    enable = mkEnableOption "AMD GPU metrics collection for Prometheus";

    interval = mkOption {
      type = types.str;
      default = "*:0/1";
      description = "Systemd calendar expression for collection interval.";
    };
  };

  config = mkIf cfg.enable {
    # Enable DRM collector on node-exporter for basic GPU utilization metrics
    services.prometheus.exporters.node.enabledCollectors = ["drm"];

    # Textfile collector service for detailed amdgpu_top metrics
    systemd.services.amdgpu-metrics-collector = {
      description = "Collect AMD GPU metrics for Prometheus";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = metricsScript;
        User = "root";
        Group = "root";
      };
    };

    systemd.timers.amdgpu-metrics-collector = {
      description = "Collect AMD GPU metrics periodically";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.interval;
        Persistent = true;
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/prometheus-node-exporter-text-files 0755 root root - -"
    ];
  };
}
