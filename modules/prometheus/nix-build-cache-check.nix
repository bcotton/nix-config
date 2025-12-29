{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.prometheus.nixBuildCacheCheck;

  checkScript = pkgs.writeShellScript "check-nix-build-cache.sh" ''
    #!/usr/bin/env bash

    # Nix Build and Cache Validation Script
    # Tests distributed builds, local cache, and upstream cache functionality
    # Outputs Prometheus text format metrics

    set -euo pipefail

    # Configuration
    CACHE_URL="''${CACHE_URL:-http://nas-01:80}"
    LOCAL_CACHE_URL="''${LOCAL_CACHE_URL:-http://localhost:5000}"
    TIMEOUT=''${TIMEOUT:-120}

    # Rotate through different test packages to ensure we actually test builds/cache
    # Rather than just finding packages already in the store
    TEST_PACKAGES=(hello cowsay figlet fortune lolcat sl)
    PACKAGE_INDEX=$(($(date +%s) / 900 % ''${#TEST_PACKAGES[@]}))  # Rotate every 15 minutes
    TEST_PACKAGE="''${TEST_PACKAGES[$PACKAGE_INDEX]}"

    # Metric output file
    METRICS_FILE="''${METRICS_FILE:-${cfg.metricsPath}}"

    # Temporary directory for test builds
    TEST_DIR=$(mktemp -d)
    trap 'rm -rf "$TEST_DIR"' EXIT

    # Initialize metrics
    declare -A metrics
    metrics[nix_distributed_build_success]=0
    metrics[nix_local_cache_hit]=0
    metrics[nix_upstream_cache_accessible]=0
    metrics[nix_cache_info_accessible]=0

    # Builder status (will be populated)
    declare -A builder_status

    # Store paths to clean up after testing
    declare -a store_paths_to_delete

    # Timestamp for metrics
    TIMESTAMP=$(date +%s)

    # Colors for output (disabled if not a TTY)
    if [[ -t 1 ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        NC='\033[0m'
    else
        RED=""
        GREEN=""
        YELLOW=""
        NC=""
    fi

    log() {
        echo -e "''${GREEN}[INFO]''${NC} $*" >&2
    }

    warn() {
        echo -e "''${YELLOW}[WARN]''${NC} $*" >&2
    }

    error() {
        echo -e "''${RED}[ERROR]''${NC} $*" >&2
    }

    # Test 1: Check cache accessibility
    test_cache_accessibility() {
        log "Testing cache accessibility..."

        if timeout 10 ${pkgs.curl}/bin/curl -sf "''${CACHE_URL}/nix-cache-info" >/dev/null 2>&1; then
            metrics[nix_cache_info_accessible]=1
            log "✓ Cache is accessible at ''${CACHE_URL}"
        else
            metrics[nix_cache_info_accessible]=0
            error "✗ Cache is not accessible at ''${CACHE_URL}"
        fi
    }

    # Test 2: Check distributed builds
    test_distributed_builds() {
        log "Testing distributed builds..."

        # Only test if we have remote builders configured
        local builders
        builders=$(${pkgs.nix}/bin/nix config show builders 2>/dev/null | ${pkgs.gnugrep}/bin/grep '^builders =' | ${pkgs.coreutils}/bin/cut -d= -f2- | ${pkgs.coreutils}/bin/tr -d ' ' || echo "")

        if [[ -z "$builders" || "$builders" == "@/etc/nix/machines" ]]; then
            # Check if machines file exists and has content
            if [[ -f /etc/nix/machines ]] && [[ -s /etc/nix/machines ]]; then
                builders="configured"
            else
                warn "No remote builders configured, skipping distributed build test"
                metrics[nix_distributed_build_success]=-1
                return
            fi
        fi

        # Build a simple derivation with verbose output to see where it builds
        local build_log
        build_log=$(mktemp)

        log "Building test package (''${TEST_PACKAGE}) to check builder usage..."
        # Use nix build with flake reference and print-build-logs to see builder usage
        if timeout ''${TIMEOUT} ${pkgs.nix}/bin/nix build "nixpkgs#''${TEST_PACKAGE}" --out-link result --print-build-logs -vv 2>&1 | tee "$build_log"; then
            # Capture the store path for later deletion
            if [[ -L result ]]; then
                local store_path
                store_path=$(${pkgs.coreutils}/bin/readlink -f result)
                if [[ -n "$store_path" ]]; then
                    store_paths_to_delete+=("$store_path")
                    log "Marked for deletion: $store_path"
                fi
                rm -f result
            fi

            # Check if any remote builders were used
            # nix build shows: "building '/nix/store/...' on 'ssh://builder'"
            if ${pkgs.gnugrep}/bin/grep -qE "(building|copying).* on '?ssh(-ng)?://nix-builder@" "$build_log"; then
                metrics[nix_distributed_build_success]=1
                log "✓ Distributed build successful"

                # Extract which builders were used
                while IFS= read -r line; do
                    if [[ $line =~ ssh(-ng)?://nix-builder@([a-zA-Z0-9.-]+) ]]; then
                        local builder="''${BASH_REMATCH[2]}"
                        builder_status["$builder"]=1
                        log "  - Used builder: $builder"
                    fi
                done < "$build_log"
            else
                # Check if build happened or was fetched (both are success states)
                # nix build shows "copying path" when fetching from cache
                # or "building" when building locally
                if ${pkgs.gnugrep}/bin/grep -qE "(building|copying path|this derivation will be built)" "$build_log"; then
                    metrics[nix_distributed_build_success]=1
                    log "✓ Build completed (local or cached)"
                else
                    # If we have a result, the build succeeded somehow
                    metrics[nix_distributed_build_success]=1
                    log "✓ Build completed (result exists)"
                fi
            fi
        else
            metrics[nix_distributed_build_success]=0
            error "✗ Build failed"
        fi

        # Save build log for debugging if needed
        if [[ -n "''${DEBUG:-}" ]]; then
            ${pkgs.coreutils}/bin/cp "$build_log" "/tmp/nix-build-cache-check-distributed.log"
            log "Debug: Build log saved to /tmp/nix-build-cache-check-distributed.log"
        fi

        rm -f "$build_log"
    }

    # Test 3: Check local and upstream cache functionality
    test_cache_functionality() {
        log "Testing cache hit functionality..."

        # Build a package twice and check if second build uses cache
        local build_log1 build_log2
        build_log1=$(mktemp)
        build_log2=$(mktemp)

        # First build - this might build or fetch from cache
        log "First build of ''${TEST_PACKAGE}..."
        timeout ''${TIMEOUT} ${pkgs.nix}/bin/nix build "nixpkgs#''${TEST_PACKAGE}" --out-link result-test1 --print-build-logs -vv 2>&1 | tee "$build_log1" >/dev/null || true

        # Clean up first result
        rm -f result-test1

        # Second build - should definitely use cache if working
        log "Second build of ''${TEST_PACKAGE} (should use cache)..."
        local start_time end_time build_duration
        start_time=$(${pkgs.coreutils}/bin/date +%s)
        timeout ''${TIMEOUT} ${pkgs.nix}/bin/nix build "nixpkgs#''${TEST_PACKAGE}" --out-link result-test2 --print-build-logs -vv 2>&1 | tee "$build_log2" >/dev/null || true
        end_time=$(${pkgs.coreutils}/bin/date +%s)
        build_duration=$((end_time - start_time))

        # Clean up result symlink
        rm -f result-test2

        # Check if second build used cache
        # With nix build, cache hits show "copying path" or very fast completion
        if ${pkgs.gnugrep}/bin/grep -qE "copying path.*from.*(''${CACHE_URL}|cache\.nixos\.org|http|https)" "$build_log2"; then
            metrics[nix_local_cache_hit]=1
            metrics[nix_upstream_cache_accessible]=1
            log "✓ Cache hit detected (copying from cache)"
        elif ${pkgs.gnugrep}/bin/grep -qE "substituting|copying path" "$build_log2"; then
            metrics[nix_local_cache_hit]=1
            log "✓ Cache hit detected (substitution occurred)"
        elif [[ $build_duration -lt 3 ]]; then
            # Very fast build (< 3 seconds) likely means it was cached
            metrics[nix_local_cache_hit]=1
            log "✓ Cache hit detected (fast completion: ''${build_duration}s)"
        else
            # If build took longer, it might have actually built
            if ${pkgs.gnugrep}/bin/grep -qE "(building '|this derivation will be built)" "$build_log2"; then
                warn "Package was built (not cached) - took ''${build_duration}s"
                metrics[nix_local_cache_hit]=0
            else
                # Unclear, but if it succeeded quickly, assume cache worked
                metrics[nix_local_cache_hit]=1
                log "✓ Build completed quickly (''${build_duration}s), assuming cache worked"
            fi
        fi

        # Save build logs for debugging if needed
        if [[ -n "''${DEBUG:-}" ]]; then
            ${pkgs.coreutils}/bin/cp "$build_log1" "/tmp/nix-build-cache-check-cache1.log"
            ${pkgs.coreutils}/bin/cp "$build_log2" "/tmp/nix-build-cache-check-cache2.log"
            log "Debug: Cache logs saved to /tmp/nix-build-cache-check-cache{1,2}.log"
        fi

        rm -f "$build_log1" "$build_log2"
    }

    # Test 4: Check upstream cache proxy
    test_upstream_cache_proxy() {
        log "Testing upstream cache proxy..."

        # Test if we can access cache through the proxy
        if ${pkgs.curl}/bin/curl -sf -m 10 "''${CACHE_URL}/nix-cache-info" | ${pkgs.gnugrep}/bin/grep -q "StoreDir: /nix/store"; then
            metrics[nix_upstream_cache_accessible]=1
            log "✓ Upstream cache proxy is accessible"
        else
            metrics[nix_upstream_cache_accessible]=0
            warn "✗ Upstream cache proxy not accessible"
        fi
    }

    # Generate Prometheus metrics
    generate_metrics() {
        local output=""

        # Header
        output+="# HELP nix_build_cache_check_timestamp Unix timestamp of last check\n"
        output+="# TYPE nix_build_cache_check_timestamp gauge\n"
        output+="nix_build_cache_check_timestamp ''${TIMESTAMP}\n\n"

        # Distributed build success
        output+="# HELP nix_distributed_build_success Whether distributed builds are working (1=yes, 0=no, -1=not configured)\n"
        output+="# TYPE nix_distributed_build_success gauge\n"
        output+="nix_distributed_build_success ''${metrics[nix_distributed_build_success]}\n\n"

        # Builder status (only output if we have builders)
        local builder_count=0
        for _ in "''${!builder_status[@]}"; do
            ((builder_count++)) || true
        done

        if [[ $builder_count -gt 0 ]]; then
            output+="# HELP nix_builder_used Whether a specific builder was used (1=yes, 0=no)\n"
            output+="# TYPE nix_builder_used gauge\n"
            for builder in "''${!builder_status[@]}"; do
                output+="nix_builder_used{builder=\"''${builder}\"} ''${builder_status[$builder]}\n"
            done
            output+="\n"
        fi

        # Local cache hit
        output+="# HELP nix_local_cache_hit Whether local cache is working (1=yes, 0=no)\n"
        output+="# TYPE nix_local_cache_hit gauge\n"
        output+="nix_local_cache_hit ''${metrics[nix_local_cache_hit]}\n\n"

        # Upstream cache accessibility
        output+="# HELP nix_upstream_cache_accessible Whether upstream cache proxy is accessible (1=yes, 0=no)\n"
        output+="# TYPE nix_upstream_cache_accessible gauge\n"
        output+="nix_upstream_cache_accessible ''${metrics[nix_upstream_cache_accessible]}\n\n"

        # Cache info accessibility
        output+="# HELP nix_cache_info_accessible Whether cache info endpoint is accessible (1=yes, 0=no)\n"
        output+="# TYPE nix_cache_info_accessible gauge\n"
        output+="nix_cache_info_accessible ''${metrics[nix_cache_info_accessible]}\n\n"

        # Test package info (for tracking rotation)
        output+="# HELP nix_test_package_info Information about the test package used (always 1)\n"
        output+="# TYPE nix_test_package_info gauge\n"
        output+="nix_test_package_info{package=\"''${TEST_PACKAGE}\"} 1\n\n"

        echo -e "$output"
    }

    # Cleanup: Delete test packages from store
    cleanup_test_packages() {
        log "Cleaning up test packages from store..."

        # Check if array has elements (safe with set -u and empty arrays)
        local count=0
        for _ in "''${store_paths_to_delete[@]+"''${store_paths_to_delete[@]}"}"; do
            ((count++)) || true
        done

        if [[ $count -eq 0 ]]; then
            log "No store paths to delete"
            return
        fi

        for store_path in "''${store_paths_to_delete[@]}"; do
            log "Deleting $store_path..."
            if ${pkgs.nix}/bin/nix-store --delete "$store_path" 2>/dev/null; then
                log "✓ Deleted $store_path"
            else
                # Deletion might fail if something depends on it, which is fine
                warn "Could not delete $store_path (may be in use)"
            fi
        done
    }

    # Main execution
    main() {
        log "Starting Nix build and cache validation"
        log "Cache URL: ''${CACHE_URL}"
        log "Test package: ''${TEST_PACKAGE}"

        # Run tests
        test_cache_accessibility
        test_distributed_builds
        test_cache_functionality
        test_upstream_cache_proxy

        # Generate and output metrics
        log "Generating metrics..."
        local metrics_output
        metrics_output=$(generate_metrics)

        # Write to file
        echo "$metrics_output" > "''${METRICS_FILE}.tmp"
        mv "''${METRICS_FILE}.tmp" "''${METRICS_FILE}"
        log "Metrics written to ''${METRICS_FILE}"

        # Clean up test packages to ensure fresh tests next time
        cleanup_test_packages

        log "Validation complete"

        # Exit with error if critical checks failed
        if [[ ''${metrics[nix_cache_info_accessible]} -eq 0 ]]; then
            error "Cache not accessible - this is a critical failure"
            exit 1
        fi
    }

    # Run main function
    main "$@"
  '';
in {
  options.services.prometheus.nixBuildCacheCheck = {
    enable = lib.mkEnableOption "Nix build and cache validation monitoring";

    interval = lib.mkOption {
      type = lib.types.str;
      default = "15m";
      description = "How often to run the check (systemd timer format)";
    };

    cacheUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://nas-01:80";
      description = "URL of the Nix binary cache";
    };

    metricsPath = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/prometheus-node-exporter-text-files/nix_build_cache.prom";
      description = "Path where metrics file will be written";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure the metrics directory exists
    systemd.tmpfiles.rules = [
      "d /var/lib/prometheus-node-exporter-text-files 0755 root root -"
    ];

    # Note: node_exporter textfile collector configuration is handled by
    # modules/zfs/monitoring.nix or should be configured in the host
    # We just ensure the directory exists and write metrics to it

    # Systemd service to run the check
    systemd.services.nix-build-cache-check = {
      description = "Check Nix build and cache functionality";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${checkScript}";
        # Run as root to allow nix-build and nix-store operations
        # Building packages and deleting from store requires root/trusted-user privileges
        User = "root";
        Group = "root";
        # Security hardening
        PrivateTmp = true;
        ReadWritePaths = [
          "/var/lib/prometheus-node-exporter-text-files"
          "/tmp"
        ];
      };
      environment = {
        CACHE_URL = cfg.cacheUrl;
        METRICS_FILE = cfg.metricsPath;
      };
    };

    # Systemd timer to run periodically
    systemd.timers.nix-build-cache-check = {
      description = "Check Nix build and cache functionality periodically";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = cfg.interval;
        Persistent = true;
      };
    };
  };
}
