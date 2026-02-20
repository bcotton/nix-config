{
  config,
  lib,
  pkgs,
  hostName,
  ...
}:
with lib; let
  cfg = config.services.clubcotton.auto-upgrade;

  # Build the health check script from configuration
  healthCheckScript = pkgs.writeShellScript "auto-upgrade-health-check" ''
    set -euo pipefail

    TIMEOUT=${toString cfg.healthChecks.timeout}
    RETRY_DELAY=${toString cfg.healthChecks.retryDelay}
    DEADLINE=$(($(date +%s) + TIMEOUT))

    check_all() {
      local failed=0

      # Ping checks
      ${concatMapStringsSep "\n" (target: ''
        if ! ${pkgs.iputils}/bin/ping -c 1 -W 3 ${escapeShellArg target} >/dev/null 2>&1; then
          echo "FAIL: ping ${target}"
          failed=1
        else
          echo "OK: ping ${target}"
        fi
      '')
      cfg.healthChecks.pingTargets}

      # DNS resolution checks
      ${concatMapStringsSep "\n" (domain: ''
        if ! ${pkgs.dig}/bin/dig +short +timeout=3 ${escapeShellArg domain} >/dev/null 2>&1; then
          echo "FAIL: dns ${domain}"
          failed=1
        else
          echo "OK: dns ${domain}"
        fi
      '')
      cfg.healthChecks.dnsQueries}

      # Systemd service checks
      ${concatMapStringsSep "\n" (service: ''
        if ! systemctl is-active --quiet ${escapeShellArg service}; then
          echo "FAIL: service ${service}"
          failed=1
        else
          echo "OK: service ${service}"
        fi
      '')
      cfg.healthChecks.services}

      # TCP port checks
      ${concatMapStringsSep "\n" (check: ''
        if ! ${pkgs.bash}/bin/bash -c 'echo > /dev/tcp/${check.host}/${toString check.port}' 2>/dev/null; then
          echo "FAIL: tcp ${check.host}:${toString check.port}"
          failed=1
        else
          echo "OK: tcp ${check.host}:${toString check.port}"
        fi
      '')
      cfg.healthChecks.tcpPorts}

      # HTTP endpoint checks
      ${concatMapStringsSep "\n" (url: ''
        if ! ${pkgs.curl}/bin/curl -sf -o /dev/null --max-time 10 ${escapeShellArg url}; then
          echo "FAIL: http ${url}"
          failed=1
        else
          echo "OK: http ${url}"
        fi
      '')
      cfg.healthChecks.httpEndpoints}

      # Extra script
      ${optionalString (cfg.healthChecks.extraScript != "") ''
      if ! (${cfg.healthChecks.extraScript}); then
        echo "FAIL: extra health check script"
        failed=1
      else
        echo "OK: extra health check script"
      fi
    ''}

      return $failed
    }

    echo "Running health checks (timeout: ''${TIMEOUT}s, retry delay: ''${RETRY_DELAY}s)..."

    while true; do
      if check_all; then
        echo "All health checks passed."
        exit 0
      fi

      NOW=$(date +%s)
      if [ "$NOW" -ge "$DEADLINE" ]; then
        echo "Health checks timed out after ''${TIMEOUT}s."
        exit 1
      fi

      REMAINING=$((DEADLINE - NOW))
      echo "Some checks failed. Retrying in ''${RETRY_DELAY}s (''${REMAINING}s remaining)..."
      sleep "$RETRY_DELAY"
    done
  '';

  # Main upgrade script
  upgradeScript = pkgs.writeShellScript "auto-upgrade" ''
    set -euo pipefail

    FLAKE=${escapeShellArg cfg.flake}
    HOSTNAME=${escapeShellArg hostName}

    echo "=== Auto-upgrade started at $(date) ==="
    echo "Host: $HOSTNAME"
    echo "Flake: $FLAKE"

    # Phase 1: Build the new configuration
    echo ""
    echo "=== Phase 1: Building new configuration ==="
    if ! ${config.nix.package}/bin/nix build \
        "''${FLAKE}#nixosConfigurations.''${HOSTNAME}.config.system.build.toplevel" \
        --no-link --print-out-paths; then
      echo "FATAL: Build failed. Aborting upgrade."
      ${optionalString (cfg.onFailure != "") cfg.onFailure}
      exit 1
    fi

    # Phase 2: Activate with test (non-persistent)
    echo ""
    echo "=== Phase 2: Activating with nixos-rebuild test ==="
    if ! ${config.system.build.nixos-rebuild}/bin/nixos-rebuild test --flake "''${FLAKE}#''${HOSTNAME}"; then
      echo "FATAL: nixos-rebuild test failed. System unchanged (no bootloader update)."
      echo "A reboot will return to the previous generation."
      ${optionalString cfg.allowReboot ''
      echo "Rebooting to restore previous generation..."
      ${pkgs.systemd}/bin/systemctl reboot
    ''}
      ${optionalString (cfg.onFailure != "") cfg.onFailure}
      exit 1
    fi

    # Phase 3: Health checks
    echo ""
    echo "=== Phase 3: Running health checks ==="
    if ! ${healthCheckScript}; then
      echo "FATAL: Health checks failed after nixos-rebuild test."
      echo "The test activation is non-persistent. A reboot restores the previous generation."
      ${optionalString cfg.allowReboot ''
      echo "Rebooting to restore previous generation..."
      ${pkgs.systemd}/bin/systemctl reboot
    ''}
      ${optionalString (cfg.onFailure != "") cfg.onFailure}
      exit 1
    fi

    # Phase 4: Persist with switch
    echo ""
    echo "=== Phase 4: Health checks passed! Running nixos-rebuild switch ==="
    if ! ${config.system.build.nixos-rebuild}/bin/nixos-rebuild switch --flake "''${FLAKE}#''${HOSTNAME}"; then
      echo "WARNING: nixos-rebuild switch failed, but test activation is still running."
      echo "The system is functional but the bootloader was not updated."
      echo "A reboot will return to the previous generation."
      ${optionalString (cfg.onFailure != "") cfg.onFailure}
      exit 1
    fi

    echo ""
    echo "=== Upgrade completed successfully at $(date) ==="
    ${optionalString (cfg.onSuccess != "") cfg.onSuccess}
  '';
in {
  options.services.clubcotton.auto-upgrade = {
    enable = mkEnableOption "pull-based auto-upgrade with health checks";

    flake = mkOption {
      type = types.str;
      example = "git+https://forgejo.example.com/user/nix-config?ref=main";
      description = "Flake URI to pull configuration from.";
    };

    dates = mkOption {
      type = types.str;
      default = "04:00";
      example = "03:00";
      description = "Systemd calendar expression for the upgrade timer.";
    };

    randomizedDelaySec = mkOption {
      type = types.str;
      default = "15min";
      description = "Random delay added to the timer to stagger upgrades across the fleet.";
    };

    healthChecks = {
      pingTargets = mkOption {
        type = types.listOf types.str;
        default = ["192.168.5.1"];
        description = "IP addresses to ping after activation.";
      };

      dnsQueries = mkOption {
        type = types.listOf types.str;
        default = ["google.com"];
        description = "Domain names to resolve after activation.";
      };

      services = mkOption {
        type = types.listOf types.str;
        default = ["sshd" "tailscaled"];
        description = "Systemd services that must be active after activation.";
      };

      tcpPorts = mkOption {
        type = types.listOf (types.submodule {
          options = {
            host = mkOption {
              type = types.str;
              default = "127.0.0.1";
              description = "Host to check.";
            };
            port = mkOption {
              type = types.port;
              description = "TCP port that must be listening.";
            };
          };
        });
        default = [];
        description = "TCP host:port pairs to verify are listening after activation.";
      };

      httpEndpoints = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["http://127.0.0.1:8080/health"];
        description = "HTTP URLs that must return 2xx after activation.";
      };

      extraScript = mkOption {
        type = types.lines;
        default = "";
        description = "Additional shell commands for health checks. Exit non-zero to signal failure.";
      };

      extraScriptPackages = mkOption {
        type = types.listOf types.package;
        default = [];
        description = "Packages to add to PATH for the extraScript health check (e.g., incus, gawk).";
      };

      timeout = mkOption {
        type = types.int;
        default = 120;
        description = "Maximum seconds to retry health checks before giving up.";
      };

      retryDelay = mkOption {
        type = types.int;
        default = 5;
        description = "Seconds to wait between health check retry attempts.";
      };
    };

    allowReboot = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically reboot on failed health checks to restore the previous generation.";
    };

    onSuccess = mkOption {
      type = types.lines;
      default = "";
      description = "Shell commands to run after a successful upgrade (e.g., webhook notification).";
    };

    onFailure = mkOption {
      type = types.lines;
      default = "";
      description = "Shell commands to run after a failed upgrade (e.g., alert notification).";
    };
  };

  config = mkIf cfg.enable {
    # Main upgrade service
    systemd.services.auto-upgrade = {
      description = "Pull-based NixOS auto-upgrade with health checks";
      after = ["network-online.target"];
      wants = ["network-online.target"];

      # Never restart mid-run — this service triggers nixos-rebuild,
      # which activates a new config that would try to restart us.
      restartIfChanged = false;

      # Prevent concurrent runs
      serviceConfig = {
        Type = "oneshot";
        ExecStart = upgradeScript;
        TimeoutStartSec = "30min";

        # Logging
        StandardOutput = "journal+console";
        StandardError = "journal+console";
      };

      path = with pkgs;
        [
          config.nix.package
          gitMinimal
          coreutils
          gawk
          gnugrep
          gnused
          findutils
          gnutar
          gzip
          xz
        ]
        ++ cfg.healthChecks.extraScriptPackages;
    };

    # Timer to trigger upgrades on schedule
    systemd.timers.auto-upgrade = {
      description = "Timer for pull-based NixOS auto-upgrade";
      wantedBy = ["timers.target"];

      timerConfig = {
        OnCalendar = cfg.dates;
        RandomizedDelaySec = cfg.randomizedDelaySec;
        Persistent = true;
      };
    };

    # Future: systemd-boot boot counting for automatic fallback on failed boots
    # When NixOS adds boot.loader.systemd-boot.counters.enable, uncomment:
    # boot.loader.systemd-boot.counters = {
    #   enable = true;
    #   tries = 3;
    # };
  };
}
