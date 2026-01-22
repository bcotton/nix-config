# Run interactively:  nix run '.#checks.x86_64-linux.zfs-raidz1.driverInteractive'
# Note: SSH access not available for disko tests (use machine.shell_interact() in Python REPL)
{
  nixpkgs,
  pkgs ? import nixpkgs {},
  lib ? pkgs.lib,
  disko,
}: let
  diskoLib = import (disko + "/lib/default.nix") {
    inherit lib;
    makeTest = import (nixpkgs + "/nixos/tests/make-test-python.nix");
    eval-config = import (nixpkgs + "/nixos/lib/eval-config.nix");
  };
  makeDiskoTest = diskoLib.testLib.makeDiskoTest;
  zfsLib = import ./lib.nix {inherit lib;};

  # Pool names
  rootPool = "zroot";
  dataPool = "tank";

  # Test configuration combining root filesystem and RAIDZ1 pool
  testConfig = {
    disko.devices =
      lib.recursiveUpdate
      # Root filesystem on single disk
      (zfsLib.makeZfsSingleRootConfig {
        poolname = rootPool;
        disk = "/dev/vda";
        swapSize = "2G";
        useStandardRootFilesystems = true;
        reservedSize = "2M";
      })
      # Additional RAIDZ1 pool
      (zfsLib.makeZfsRaidz1Config {
        poolname = rootPool;
        dataPoolName = dataPool;
        disks = ["/dev/vdb" "/dev/vdc" "/dev/vdd" "/dev/vde"];
        reservedSize = "2M";
        filesystems = {
          "data" = {
            type = "zfs_fs";
            mountpoint = "/tank/data";
            options = {
              compression = "lz4";
              recordsize = "1M";
            };
          };
          "backup" = {
            type = "zfs_fs";
            mountpoint = "/tank/backup";
            options = {
              compression = "lz4";
              recordsize = "1M";
              copies = "2";
            };
          };
        };
      });
  };
in
  makeDiskoTest {
    inherit pkgs;
    name = "zfs-raidz1";
    disko-config = testConfig;
    extraInstallerConfig = {
      networking.hostId = "8425e349";
    };
    extraSystemConfig = {
      networking.hostId = "8425e349";
    };
    extraTestScript = ''
      def assert_property(ds, property, expected_value):
          out = machine.succeed(f"zfs get -H {property} {ds} -o value").rstrip()
          assert (
              out == expected_value
          ), f"Expected {property}={expected_value} on {ds}, got: {out}"

      # Helper function for pool status checks
      def check_pool_status(pool, field, expected):
          status = machine.succeed(f"zpool get -H {field} {pool} -o value").rstrip()
          assert status == expected, f"Expected pool {field} to be {expected}, got: {status}"

      # Test root pool
      check_pool_status("${rootPool}", "health", "ONLINE")
      check_pool_status("${rootPool}", "ashift", "12")
      check_pool_status("${rootPool}", "autotrim", "on")

      # Test RAIDZ1 pool
      check_pool_status("${dataPool}", "health", "ONLINE")
      check_pool_status("${dataPool}", "ashift", "12")
      check_pool_status("${dataPool}", "autotrim", "on")

      # Verify RAIDZ1 configuration and all components are ONLINE
      status = machine.succeed("zpool status ${dataPool}")
      assert "raidz1" in status, "Expected RAIDZ1 configuration"

      # Count ONLINE components (pool + raidz1 vdev + 4 drives = 6)
      # Exclude the "state:" line at the top
      online_count = machine.succeed("zpool status ${dataPool} | grep ONLINE | grep -v state | wc -l").strip()
      assert int(online_count) == 6, f"Expected 6 ONLINE components (pool + raidz1 + 4 drives), got {online_count}"

      # Verify dataset structure and properties
      datasets = machine.succeed("zfs list -H -o name").rstrip().split('\n')
      expected_datasets = [
          "${rootPool}", "${rootPool}/local/root", "${rootPool}/safe/home",
          "${rootPool}/local/lib", "${rootPool}/local/log", "${rootPool}/local/reserved",
          "${dataPool}", "${dataPool}/data", "${dataPool}/backup"
      ]
      for ds in expected_datasets:
          assert ds in datasets, f"Expected dataset {ds} not found"

      # Test ZFS properties for root pool
      assert_property("${rootPool}", "compression", "lz4")
      assert_property("${rootPool}/safe/home", "compression", "lz4")
      assert_property("${rootPool}/safe/home", "com.sun:auto-snapshot", "true")

      # Test ZFS properties for RAIDZ1 pool
      assert_property("${dataPool}/data", "compression", "lz4")
      assert_property("${dataPool}/data", "recordsize", "1M")
      assert_property("${dataPool}/backup", "compression", "lz4")
      assert_property("${dataPool}/backup", "recordsize", "1M")
      assert_property("${dataPool}/backup", "copies", "2")

      # Test mountpoints
      machine.succeed("mountpoint /")
      machine.succeed("mountpoint /home")
      machine.succeed("mountpoint /boot")
      machine.succeed("mountpoint /tank/data")
      machine.succeed("mountpoint /tank/backup")

      # Test swap
      machine.succeed("swapon -s | grep /dev/")

      # Test boot loader
      machine.succeed("test -d /boot/loader")
      machine.succeed("test -d /boot/EFI")
    '';
  }
