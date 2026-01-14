# Nix Flake Starter

A multi-host, multi-platform Nix flake template for managing NixOS and macOS (nix-darwin) systems. Use this as a starting point for your own configuration.

## Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled
- [just](https://github.com/casey/just) command runner (optional but recommended)

---

## Installing Nix

### On macOS (Darwin)

```bash
# Install Nix using the Determinate Systems installer (recommended)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Or use the official installer
sh <(curl -L https://nixos.org/nix/install)
```

After installation, ensure flakes are enabled. Add to `~/.config/nix/nix.conf`:

```
experimental-features = nix-command flakes
```

### On Linux

```bash
# Install Nix
sh <(curl -L https://nixos.org/nix/install) --daemon

# Enable flakes in ~/.config/nix/nix.conf
experimental-features = nix-command flakes
```

---

## Quick Start

1. Clone this repository
2. Add your user (see below)
3. Boot the test VM to experiment (Linux) or apply directly (macOS)
4. Customize and apply to your real machines

---

## Adding a New User

To use this flake, you'll need to replace the example user (`bcotton`) with your own. Each user needs two files:

### Step 1: Create the system user file

Create `users/yourusername.nix`:

```nix
{
  pkgs,
  ...
}: {
  users.users.yourusername = {
    isNormalUser = true;
    shell = pkgs.zsh;  # or pkgs.bash
    extraGroups = ["wheel"];  # wheel grants sudo access

    # Generate with: mkpasswd -m sha-512
    hashedPassword = "$6$YOUR_HASHED_PASSWORD_HERE";

    # Or use initialPassword for testing (change on first login):
    # initialPassword = "changeme";

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 YOUR_PUBLIC_KEY your@email.com"
    ];
  };
}
```

### Step 2: Create the home-manager file

Create `home/yourusername.nix`:

```nix
{
  pkgs,
  ...
}: {
  home.stateVersion = "25.11";

  programs.git = {
    enable = true;
    settings.user = {
      name = "Your Name";
      email = "your@email.com";
    };
  };

  programs.home-manager.enable = true;

  # Add your preferred packages
  home.packages = with pkgs; [
    ripgrep
    fd
    htop
  ];
}
```

### Step 3: Update host configuration

Edit the appropriate flake module to use your username:

**For NixOS hosts** - Edit `flake-modules/nixos.nix`:
```nix
test-vm = mkNixosSystem {
  system = "x86_64-linux";
  hostName = "test-vm";
  usernames = ["yourusername"];  # Change this
};
```

**For Darwin hosts** - Edit `flake-modules/darwin.nix`:
```nix
your-mac = mkDarwinSystem {
  system = "aarch64-darwin";
  hostName = "your-mac";
  username = "yourusername";  # Change this
};
```

### Step 4: Update the test-vm auto-login (NixOS only)

Edit `hosts/nixos/test-vm/default.nix` and change the auto-login user:

```nix
services.getty.autologinUser = "yourusername";
```

---

## Adding New Hosts

### Adding a NixOS Host

1. **Create the host directory:**
   ```bash
   mkdir -p hosts/nixos/your-hostname
   ```

2. **Create `hosts/nixos/your-hostname/default.nix`:**
   ```nix
   {
     pkgs,
     lib,
     ...
   }: {
     # Import hardware configuration (generate with nixos-generate-config)
     imports = [./hardware-configuration.nix];

     boot.loader.systemd-boot.enable = true;
     boot.loader.efi.canTouchEfiVariables = true;

     networking.useDHCP = true;

     # Add host-specific configuration here

     system.stateVersion = "25.11";
   }
   ```

3. **Add to `flake-modules/nixos.nix`:**
   ```nix
   flake.nixosConfigurations = {
     # ... existing hosts ...
     your-hostname = mkNixosSystem {
       system = "x86_64-linux";
       hostName = "your-hostname";
       usernames = ["yourusername"];
     };
   };
   ```

4. **Build and apply:**
   ```bash
   just switch your-hostname
   ```

### Adding a Darwin (macOS) Host

1. **Create the host directory:**
   ```bash
   mkdir -p hosts/darwin/your-mac
   ```

2. **Create `hosts/darwin/your-mac/default.nix`:**
   ```nix
   {
     pkgs,
     ...
   }: {
     # Enable Homebrew integration (optional)
     homebrew = {
       enable = true;
       onActivation.autoUpdate = true;
       casks = [
         # "firefox"
         # "iterm2"
       ];
     };

     # macOS system preferences
     system.defaults = {
       dock.autohide = true;
       finder.AppleShowAllExtensions = true;
     };

     # Required for nix-darwin
     services.nix-daemon.enable = true;
     nix.settings.experimental-features = ["nix-command" "flakes"];

     system.stateVersion = 5;
   }
   ```

3. **Add to `flake-modules/darwin.nix`:**
   ```nix
   flake.darwinConfigurations = {
     # ... existing hosts ...
     your-mac = mkDarwinSystem {
       system = "aarch64-darwin";  # or "x86_64-darwin" for Intel
       hostName = "your-mac";
       username = "yourusername";
     };
   };
   ```

4. **Build and apply:**
   ```bash
   # First time - bootstrap nix-darwin
   nix build .#darwinConfigurations.your-mac.system
   ./result/sw/bin/darwin-rebuild switch --flake .#your-mac

   # Subsequent updates
   just switch your-mac
   ```

---

## Booting the Test VM

The test VM lets you experiment with the flake without affecting your real system. It mounts this directory at `/tmp/shared` so you can edit files on your host and test changes inside the VM.

### Build and run the VM

```bash
# First time (or after changes to VM config)
just run-test-vm

# If you need to start fresh
just clean-test-vm
just run-test-vm
```

### What happens

- The VM boots in your terminal (headless/console mode)
- You're automatically logged in as your configured user
- The flake directory is mounted at `/tmp/shared`
- SSH is available on port 2222: `ssh -p 2222 yourusername@localhost`

### Exiting the VM

Press `Ctrl-A X` to quit QEMU and return to your host terminal.

---

## Applying Changes Inside the VM

The real power of this setup is iterating quickly: edit files on your host, then apply them inside the VM without rebuilding the entire VM.

### Workflow

1. **On your host**: Edit any nix files (users, home config, packages, etc.)

2. **Inside the VM**: Apply the changes

```bash
cd /tmp/shared
just vm-switch test-vm
```

Note: Use `vm-switch` instead of `switch` inside the VM. This uses the `path:` flake prefix to work around git worktree issues with shared folders.

### What you can test

- Adding/removing system packages (`hosts/common/common-packages.nix`)
- Changing user configuration (`users/yourusername.nix`)
- Modifying home-manager settings (`home/yourusername.nix`)
- Testing new NixOS modules
- Experimenting with services

### Tips

- Changes take effect immediately after `switch` completes
- If something breaks, exit and run `just clean-test-vm` to start fresh
- The VM disk persists between runs (in `test-vm.qcow2`), so installed packages and state survive reboots
- For a completely fresh start: `rm test-vm.qcow2`

---

## Project Structure

```
.
├── flake.nix                 # Main flake entry point
├── flake.lock                # Locked dependency versions
├── Justfile                  # Build commands
│
├── flake-modules/            # Flake-parts modules
│   ├── nixos.nix             # NixOS host definitions
│   └── darwin.nix            # Darwin host definitions
│
├── hosts/
│   ├── common/
│   │   ├── common-packages.nix   # Packages for all systems
│   │   ├── nixos-common.nix      # NixOS-specific settings
│   │   └── darwin-common.nix     # macOS-specific settings
│   ├── nixos/
│   │   ├── test-vm/              # Test VM configuration
│   │   └── nixhost/              # Example NixOS host
│   └── darwin/
│       └── bobs-laptop/          # Example macOS host
│
├── users/                    # System user definitions
│   └── bcotton.nix
│
├── home/                     # Home-manager configurations
│   └── bcotton.nix
│
├── modules/                  # Custom NixOS modules
├── overlays/                 # Package overlays
└── pkgs/                     # Custom packages
```

---

## Common Commands

| Command | Description |
|---------|-------------|
| `just run-test-vm` | Build and run the test VM |
| `just clean-test-vm` | Remove VM disk and build artifacts |
| `just build test-vm` | Build without running |
| `just switch <host>` | Build and apply configuration |
| `just vm-switch <host>` | Switch inside VM (workaround for git worktrees) |
| `just deploy <host>` | Deploy to remote NixOS host via SSH |
| `just fmt` | Format all nix files |
| `just update` | Update flake inputs |
| `just repl` | Open nix repl with flake loaded |

---

## Next Steps

Once you're comfortable with the test VM:

1. **Add a real host**: Follow the "Adding New Hosts" section above
2. **Customize packages**: Edit `hosts/common/common-packages.nix`
3. **Set up secrets**: The flake includes [agenix](https://github.com/ryantm/agenix) for encrypted secrets
4. **Remote deployment**: Use `just deploy <hostname>` to deploy to remote NixOS machines
