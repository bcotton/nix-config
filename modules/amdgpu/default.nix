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
    echo "$JSON" | $JQ -r '
      .devices[] |
      .Info as $info |
      .Sensors as $sensors |
      .VRAM as $vram |
      .gpu_activity as $activity |
      .gpu_metrics as $gm |

      # Labels
      ($info.DeviceName // "unknown") as $name |
      ($info.PCI // "unknown") as $pci |

      # Temperature metrics
      "# HELP amdgpu_temperature_celsius GPU temperature in degrees Celsius.",
      "# TYPE amdgpu_temperature_celsius gauge",
      (if $sensors["Edge Temperature"].value then
        "amdgpu_temperature_celsius{device=\"\($pci)\",name=\"\($name)\",sensor=\"edge\"} \($sensors["Edge Temperature"].value)"
      else empty end),
      (if $sensors["Junction Temperature"].value then
        "amdgpu_temperature_celsius{device=\"\($pci)\",name=\"\($name)\",sensor=\"junction\"} \($sensors["Junction Temperature"].value)"
      else empty end),
      (if $sensors["Memory Temperature"].value then
        "amdgpu_temperature_celsius{device=\"\($pci)\",name=\"\($name)\",sensor=\"memory\"} \($sensors["Memory Temperature"].value)"
      else empty end),

      # Power metrics
      "# HELP amdgpu_power_watts GPU power draw in watts.",
      "# TYPE amdgpu_power_watts gauge",
      (if $sensors["Average Power"].value then
        "amdgpu_power_watts{device=\"\($pci)\",name=\"\($name)\"} \($sensors["Average Power"].value)"
      else empty end),

      # Power cap
      "# HELP amdgpu_power_cap_watts GPU power cap in watts.",
      "# TYPE amdgpu_power_cap_watts gauge",
      (if $info["Power Cap"].current then
        "amdgpu_power_cap_watts{device=\"\($pci)\",name=\"\($name)\"} \($info["Power Cap"].current)"
      else empty end),

      # Fan speed
      "# HELP amdgpu_fan_rpm GPU fan speed in RPM.",
      "# TYPE amdgpu_fan_rpm gauge",
      (if $sensors.Fan.value then
        "amdgpu_fan_rpm{device=\"\($pci)\",name=\"\($name)\"} \($sensors.Fan.value)"
      else empty end),
      "# HELP amdgpu_fan_max_rpm GPU maximum fan speed in RPM.",
      "# TYPE amdgpu_fan_max_rpm gauge",
      (if $sensors["Fan Max"].value then
        "amdgpu_fan_max_rpm{device=\"\($pci)\",name=\"\($name)\"} \($sensors["Fan Max"].value)"
      else empty end),

      # Clock speeds
      "# HELP amdgpu_clock_mhz GPU clock speed in MHz.",
      "# TYPE amdgpu_clock_mhz gauge",
      (if $sensors.GFX_SCLK.value then
        "amdgpu_clock_mhz{device=\"\($pci)\",name=\"\($name)\",clock=\"gfx\"} \($sensors.GFX_SCLK.value)"
      else empty end),
      (if $sensors.GFX_MCLK.value then
        "amdgpu_clock_mhz{device=\"\($pci)\",name=\"\($name)\",clock=\"mem\"} \($sensors.GFX_MCLK.value)"
      else empty end),
      (if $sensors.FCLK.value then
        "amdgpu_clock_mhz{device=\"\($pci)\",name=\"\($name)\",clock=\"fabric\"} \($sensors.FCLK.value)"
      else empty end),

      # GPU activity
      "# HELP amdgpu_gpu_busy_percent GPU utilization percentage.",
      "# TYPE amdgpu_gpu_busy_percent gauge",
      (if $activity.GFX.value != null then
        "amdgpu_gpu_busy_percent{device=\"\($pci)\",name=\"\($name)\",engine=\"gfx\"} \($activity.GFX.value)"
      else empty end),
      (if $activity.Memory.value != null then
        "amdgpu_gpu_busy_percent{device=\"\($pci)\",name=\"\($name)\",engine=\"memory\"} \($activity.Memory.value)"
      else empty end),
      (if $activity.MediaEngine.value != null then
        "amdgpu_gpu_busy_percent{device=\"\($pci)\",name=\"\($name)\",engine=\"media\"} \($activity.MediaEngine.value)"
      else empty end),

      # VRAM usage
      "# HELP amdgpu_vram_bytes GPU VRAM in bytes.",
      "# TYPE amdgpu_vram_bytes gauge",
      (if $vram["Total VRAM"].value then
        "amdgpu_vram_bytes{device=\"\($pci)\",name=\"\($name)\",type=\"total\"} \($vram["Total VRAM"].value * 1048576)"
      else empty end),
      (if $vram["Total VRAM Usage"].value then
        "amdgpu_vram_bytes{device=\"\($pci)\",name=\"\($name)\",type=\"used\"} \($vram["Total VRAM Usage"].value * 1048576)"
      else empty end),
      (if $vram["Total GTT"].value then
        "amdgpu_vram_bytes{device=\"\($pci)\",name=\"\($name)\",type=\"gtt_total\"} \($vram["Total GTT"].value * 1048576)"
      else empty end),
      (if $vram["Total GTT Usage"].value then
        "amdgpu_vram_bytes{device=\"\($pci)\",name=\"\($name)\",type=\"gtt_used\"} \($vram["Total GTT Usage"].value * 1048576)"
      else empty end),

      # Voltage
      "# HELP amdgpu_voltage_mv GPU voltage in millivolts.",
      "# TYPE amdgpu_voltage_mv gauge",
      (if $sensors.VDDGFX.value then
        "amdgpu_voltage_mv{device=\"\($pci)\",name=\"\($name)\",rail=\"gfx\"} \($sensors.VDDGFX.value)"
      else empty end),

      # PCIe link
      "# HELP amdgpu_pcie_link_speed_gen Current PCIe link generation.",
      "# TYPE amdgpu_pcie_link_speed_gen gauge",
      (if $sensors["PCIe Link Speed"].gen then
        "amdgpu_pcie_link_speed_gen{device=\"\($pci)\",name=\"\($name)\"} \($sensors["PCIe Link Speed"].gen)"
      else empty end),
      "# HELP amdgpu_pcie_link_width Current PCIe link width.",
      "# TYPE amdgpu_pcie_link_width gauge",
      (if $sensors["PCIe Link Speed"].width then
        "amdgpu_pcie_link_width{device=\"\($pci)\",name=\"\($name)\"} \($sensors["PCIe Link Speed"].width)"
      else empty end)
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
