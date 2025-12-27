# NixOS Testing Guide

This guide covers testing and debugging for the NixOS configurations and services in this repository.

## Table of Contents

- [Overview](#overview)
- [Available Tests](#available-tests)
- [Running Tests](#running-tests)
- [Interactive Test Debugging](#interactive-test-debugging)
- [SSH Access to Test VMs](#ssh-access-to-test-vms)
- [Test Structure](#test-structure)
- [Writing New Tests](#writing-new-tests)
- [Troubleshooting](#troubleshooting)

## Overview

This repository uses the NixOS testing framework to validate configurations and services. All tests are defined as flake checks and can be run individually or collectively. Every test in this repository has SSH access enabled by default for interactive debugging.

## Available Tests

All tests are available under `checks.x86_64-linux`:

### Service Tests
- **postgresql** - PostgreSQL module configuration and extensions
- **webdav** - WebDAV service with authentication and permissions
- **kavita** - Kavita manga/comic server
- **postgresql-integration** - Multi-node test with Immich and Open WebUI

### ZFS/Storage Tests
- **zfs-single-root** - Single-disk ZFS root filesystem
- **zfs-raidz1** - RAIDZ1 pool configuration with multiple disks
- **zfs-mirrored-root** - Mirrored root filesystem with dual boot partitions

## Running Tests

### Non-Interactive Mode

Run a test to completion:

```bash
# Run a specific test
nix build '.#checks.x86_64-linux.postgresql'

# Run all tests
nix flake check
```

### Interactive Mode

Run a test with an interactive Python REPL:

```bash
# Start interactive test
nix run '.#checks.x86_64-linux.postgresql.driverInteractive'
```

In the interactive REPL, you can:

```python
# Start all VMs
>>> start_all()

# Run individual test commands
>>> machine.succeed("systemctl status postgresql")

# Check service logs
>>> print(machine.succeed("journalctl -u postgresql -n 50"))

# Enter interactive shell (press Ctrl-D to exit)
>>> machine.shell_interact()

# Take a screenshot (saved to current directory)
>>> machine.screenshot("debug_screenshot")

# Get machine state
>>> machine.succeed("df -h")
>>> machine.succeed("ps aux")
```

**Important:** After running `machine.shell_interact()`, the test will pause at that point. You need to press `Ctrl-D` to exit the interactive shell and continue test execution.

## SSH Access to Test VMs

**All tests now have SSH access enabled by default** on port 2223. This allows you to debug test VMs using familiar SSH tools and workflows.

### Connecting via SSH

```bash
# Connect to a running test VM
ssh -p 2223 root@localhost
```

**No password is required** - the tests are configured with `PermitEmptyPasswords = "yes"` for easy access.

### SSH Access Workflow

1. **Start the test in interactive mode:**
   ```bash
   nix run '.#checks.x86_64-linux.postgresql.driverInteractive'
   ```

2. **In the test REPL, start the VM:**
   ```python
   >>> start_all()
   ```

3. **In a separate terminal, SSH into the VM:**
   ```bash
   ssh -p 2223 root@localhost
   ```

4. **Debug inside the VM:**
   ```bash
   # Check service status
   systemctl status postgresql

   # View logs
   journalctl -u postgresql -f

   # Inspect configuration
   cat /etc/postgresql/postgresql.conf

   # Run manual tests
   sudo -u postgres psql
   ```

5. **When done, exit SSH and continue/stop the test**

### Multi-Node Tests

For multi-node tests like `postgresql-integration`, each node has its own SSH port:

```bash
# PostgreSQL node
ssh -p 2223 root@localhost

# Immich node
ssh -p 2224 root@localhost

# Open WebUI node
ssh -p 2225 root@localhost
```

Check the test file's `interactive.nodes` configuration to see which ports are assigned to each node.

## Test Structure

### Standard NixOS Tests

Most tests follow this structure:

```nix
{nixpkgs}: {
  name = "test-name";

  # SSH configuration for interactive debugging
  interactive.nodes = let
    testLib = import ../tests/libtest.nix {};
  in {
    machine = {...}: testLib.mkSshConfig 2223;
  };

  nodes.machine = {config, pkgs, ...}: {
    # Test configuration
    imports = [ ./default.nix ];
    services.example.enable = true;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("example.service")
    machine.succeed("test command")
  '';
}
```

### Disko/ZFS Tests

ZFS tests use the disko test framework with SSH configured in `extraSystemConfig`:

```nix
{nixpkgs, pkgs, lib, disko}: let
  makeDiskoTest = ...;
in makeDiskoTest {
  inherit pkgs;
  name = "zfs-test";
  disko-config = {...};

  extraSystemConfig = {
    # Enable SSH access for interactive debugging
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "yes";
        PermitEmptyPasswords = "yes";
      };
    };
    security.pam.services.sshd.allowNullPassword = true;
    virtualisation.forwardPorts = [{
      from = "host";
      host.port = 2223;
      guest.port = 22;
    }];
  };

  extraTestScript = ''
    # Test commands
  '';
}
```

## Writing New Tests

### 1. Create Test File

Create a test file in the appropriate location:
- Service tests: `clubcotton/services/<service>/test.nix`
- Module tests: `modules/<module>/test.nix`
- Integration tests: `tests/<test-name>.nix`

### 2. Enable SSH by Default

**For standard NixOS tests**, add the interactive SSH configuration:

```nix
{nixpkgs}: {
  name = "my-test";

  # SSH configuration for interactive debugging
  interactive.nodes = let
    testLib = import ../../tests/libtest.nix {};
  in {
    machine = {...}: testLib.mkSshConfig 2223;
    # For multi-node tests, add more nodes with different ports:
    # node2 = {...}: testLib.mkSshConfig 2224;
  };

  nodes.machine = {
    # Your test configuration
  };

  testScript = ''
    # Your test script
  '';
}
```

**For disko/ZFS tests**, add SSH to `extraSystemConfig`:

```nix
extraSystemConfig = {
  # Your existing config...

  # Enable SSH access for interactive debugging
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PermitEmptyPasswords = "yes";
    };
  };
  security.pam.services.sshd.allowNullPassword = true;
  virtualisation.forwardPorts = [{
    from = "host";
    host.port = 2223;
    guest.port = 22;
  }];
};
```

### 3. Add Test to checks.nix

Register your test in `flake-modules/checks.nix`:

```nix
{inputs, ...}: {
  perSystem = {pkgs, system, lib, ...}: {
    checks = lib.optionalAttrs (system == "x86_64-linux") {
      my-test = pkgs.nixosTest (import ../path/to/test.nix {
        nixpkgs = inputs.nixpkgs;
      });
    };
  };
}
```

### 4. Add Documentation Comments

Add usage comments at the top of your test file:

```nix
# Run: nix build '.#checks.x86_64-linux.my-test'
# Interactive: nix run '.#checks.x86_64-linux.my-test.driverInteractive'
# SSH into test VM: ssh -p 2223 root@localhost
{nixpkgs}: {
  # ...
}
```

## Troubleshooting

### Test Fails to Start

```bash
# Check build logs
nix build '.#checks.x86_64-linux.postgresql' --show-trace

# Look for evaluation errors
nix eval '.#checks.x86_64-linux.postgresql' --show-trace
```

### Service Won't Start in Test

Use interactive mode with SSH to debug:

```bash
# Start interactive test
nix run '.#checks.x86_64-linux.postgresql.driverInteractive'

# In Python REPL
>>> start_all()

# In separate terminal
ssh -p 2223 root@localhost

# Inside VM
systemctl status postgresql
journalctl -u postgresql -xe
```

### VM Performance Issues

The test VMs use QEMU and may be slow. You can:

```python
# Increase VM memory (in test configuration)
virtualisation.memorySize = 4096;  # Default is usually 1024

# Increase CPUs
virtualisation.cores = 4;
```

### Port Already in Use

If port 2223 is already in use:

1. Find the process using the port:
   ```bash
   lsof -i :2223
   ```

2. Kill the old test VM or change the SSH port in the test configuration:
   ```nix
   testLib.mkSshConfig 2224  # Use different port
   ```

### SSH Connection Refused

This usually means the VM hasn't finished booting:

```python
# In test REPL, wait for SSH to be ready
>>> machine.wait_for_unit("sshd.service")
>>> machine.wait_for_open_port(22)
```

Then try SSH again from your terminal.

### Test Hangs on machine.shell_interact()

This is normal behavior! `machine.shell_interact()` pauses test execution and gives you an interactive shell. Press `Ctrl-D` to exit and continue the test.

If you want to debug without blocking test execution, use SSH instead:

```python
# Instead of machine.shell_interact(), just start the test
>>> start_all()

# Then SSH from another terminal
# Terminal 2: ssh -p 2223 root@localhost
```

### Viewing Test Logs

```python
# View specific service logs
>>> print(machine.succeed("journalctl -u servicename"))

# View all system logs
>>> print(machine.succeed("journalctl -b"))

# View last 100 lines
>>> print(machine.succeed("journalctl -n 100"))

# Follow logs in real-time (use SSH for this)
# In SSH session: journalctl -f
```

### Debugging Multi-Node Tests

For tests with multiple nodes (like `postgresql-integration`):

```python
# Start all nodes
>>> start_all()

# Check connectivity between nodes
>>> immich.succeed("ping -c 3 postgres")
>>> webui.succeed("nc -z postgres 5433")

# SSH into specific nodes (in separate terminals)
# Terminal 2: ssh -p 2223 root@localhost  # postgres node
# Terminal 3: ssh -p 2224 root@localhost  # immich node
# Terminal 4: ssh -p 2225 root@localhost  # webui node
```

### Common Test Commands

```python
# Wait for a service to start
machine.wait_for_unit("servicename.service")

# Wait for a port to open
machine.wait_for_open_port(5432)

# Run a command that should succeed
machine.succeed("test -f /some/file")

# Run a command that should fail
machine.fail("test -f /nonexistent/file")

# Wait until a command succeeds (with retries)
machine.wait_until_succeeds("curl http://localhost:8080")

# Get output of a command
output = machine.succeed("cat /etc/hostname")
print(output)
```

## Best Practices

1. **Always enable SSH** - It makes debugging much easier
2. **Use descriptive test names** - Makes it clear what's being tested
3. **Add comments** - Document usage and SSH ports at the top of test files
4. **Test incrementally** - Use interactive mode to develop tests step by step
5. **Use subtests** - Organize test scripts with `with subtest("description"):`
6. **Clean up resources** - Tests should be idempotent and clean up after themselves
7. **Document ports** - If using custom ports, document them in comments
8. **Use the test library** - Leverage `tests/libtest.nix` for common patterns

## Additional Resources

- [NixOS Testing Documentation](https://nixos.org/manual/nixos/stable/#sec-nixos-tests)
- [NixOS Test Driver API](https://nixos.org/manual/nixos/stable/index.html#sec-test-driver-api)
- [Flake-parts Documentation](https://flake.parts/)
- [Disko Testing](https://github.com/nix-community/disko/blob/master/docs/TESTING.md)
