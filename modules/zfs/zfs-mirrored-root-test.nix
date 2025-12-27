# Run interactively:  nix run '.#checks.x86_64-linux.zfs-mirrored-root.driverInteractive'
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

  # Pool name
  rootPool = "zroot";

  # Test configuration
  testConfig = {
    disko.devices = zfsLib.makeZfsMirroredRootConfig {
      poolname = rootPool;
      disks = ["/dev/vda" "/dev/vdb"];
      swapSize = "2G";
      useStandardRootFilesystems = true;
      reservedSize = "2M";
    };
  };
in
  makeDiskoTest {
    inherit pkgs;
    name = "zfs-mirrored-root";
    disko-config = testConfig;
    extraInstallerConfig = {
      networking.hostId = "8425e349";
    };
    extraSystemConfig = {
      networking.hostId = "8425e349";
      boot.loader = {
        systemd-boot.enable = lib.mkForce false;
        grub = {
          enable = true;
          devices = lib.mkForce [];
          efiSupport = true;
          efiInstallAsRemovable = true;
          mirroredBoots = [
            {
              devices = ["nodev"];
              path = "/boot0";
              efiSysMountPoint = "/boot0";
            }
            {
              devices = ["nodev"];
              path = "/boot1";
              efiSysMountPoint = "/boot1";
            }
          ];
        };
      };
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

      # Test pool health and properties
      check_pool_status("${rootPool}", "health", "ONLINE")
      check_pool_status("${rootPool}", "ashift", "12")
      check_pool_status("${rootPool}", "autotrim", "on")
      check_pool_status("${rootPool}", "delegation", "on")
      check_pool_status("${rootPool}", "multihost", "off")
      check_pool_status("${rootPool}", "readonly", "off")
      check_pool_status("${rootPool}", "autoexpand", "off")

      # Count ONLINE components (pool + raidz1 vdev + 2 drives = 4)
      # Exclude the "state:" line at the top
      online_count = machine.succeed("zpool status ${rootPool} | grep ONLINE | grep -v state | wc -l").strip()
      assert int(online_count) == 4, f"Expected 4 ONLINE components (pool + raidz1 + 2 drives), got {online_count}"

      # Verify dataset structure and properties
      datasets = machine.succeed("zfs list -H -o name").rstrip().split('\n')
      expected_datasets = ["${rootPool}", "${rootPool}/local/root", "${rootPool}/safe/home"]
      for ds in expected_datasets:
          assert ds in datasets, f"Expected dataset {ds} not found"

      # Test pool features
      features = int(machine.succeed("zpool get all ${rootPool} | grep feature@ | grep active | wc -l").strip())
      assert features > 0, "Expected some active features on the pool"

      # Test ZFS properties
      assert_property("${rootPool}", "compression", "lz4")
      assert_property("${rootPool}/safe/home", "compression", "lz4")
      assert_property("${rootPool}/safe/home", "com.sun:auto-snapshot", "true")

      # Test mountpoints
      machine.succeed("mountpoint /")
      machine.succeed("mountpoint /nix")
      machine.succeed("mountpoint /home")
      machine.succeed("mountpoint /boot0")
      machine.succeed("mountpoint /boot1")
      machine.succeed("mountpoint /var/log")
      machine.succeed("mountpoint /var/lib")


      machine.shell_interact()

      # Test swap on both disks
      swap_devices = machine.succeed("swapon -s")
      assert swap_devices.count("/dev/") == 2, "Expected two swap devices"

      # Test boot loader on both disks
      machine.succeed("test -d /boot0/kernels")
      machine.succeed("test -d /boot0/EFI")
      machine.succeed("test -d /boot1/kernels")
      machine.succeed("test -d /boot1/EFI")
    '';
  }
