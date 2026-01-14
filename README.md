# Nix Flake Starter

A multi-host, multi-platform Nix flake template for managing NixOS and macOS (nix-darwin) systems. Use this as a starting point for your own configuration.

## Table of Contents

- [Nix Flake Starter](#nix-flake-starter)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Installing Nix](#installing-nix)
    - [On macOS (Darwin)](#on-macos-darwin)
    - [On Linux](#on-linux)
  - [Quick Start](#quick-start)
  - [Adding a New User](#adding-a-new-user)
    - [Step 1: Create the system user file](#step-1-create-the-system-user-file)
    - [Step 2: Create the home-manager file](#step-2-create-the-home-manager-file)
    - [Step 3: Update host configuration](#step-3-update-host-configuration)
  - [Adding New Hosts](#adding-new-hosts)
    - [Adding a NixOS Host](#adding-a-nixos-host)
    - [Adding a Darwin (macOS) Host](#adding-a-darwin-macos-host)
  - [Booting the Test VM](#booting-the-test-vm)
    - [On Linux](#on-linux-1)
    - [On macOS (M-series Macs)](#on-macos-m-series-macs)
    - [What happens](#what-happens)
    - [Exiting the VM](#exiting-the-vm)
  - [Applying Changes Inside the VM](#applying-changes-inside-the-vm)
    - [Workflow](#workflow)
    - [What you can test](#what-you-can-test)
    - [Tips](#tips)
  - [Project Structure](#project-structure)
  - [Common Commands](#common-commands)
  - [Next Steps](#next-steps)

---

## Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled

---

## Installing Nix

### On macOS (Darwin)

```bash
# Install Nix using the Determinate Systems installer (recommended)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Or use the official installer
sh <(curl -L https://nixos.org/nix/install)
```

### On Linux

```bash
# Install Nix or use a NixOS distribution
sh <(curl -L https://nixos.org/nix/install) --daemon

# Enable flakes in ~/.config/nix/nix.conf
experimental-features = nix-command flakes
```

---

## Quick Start

**Important**: When working with flakes, you MUST `git add` new files before running `build` or `switch`.

1. Clone this repository
   ```bash
   git clone -b getting-started https://github.com/bcotton/nix-config
   cd nix-config
   ```
2. Install Nix (see above)
3. Start a shell with required packages
   ```bash
   nix-shell -p just git
   ```
4. Add your user (see [Adding a New User](#adding-a-new-user))
5. Add your machine (see [Adding New Hosts](#adding-new-hosts))
6. Build and apply
   ```bash
   just build    # Test the build
   sudo just switch  # Apply the configuration (NixOS)
   ```

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
your-hostname = mkNixosSystem {
  system = "x86_64-linux";
  hostName = "your-hostname";
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
   sudo just switch
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
     unstablePkgs,
     lib,
     inputs,
     ...
   }: let
     inherit (inputs) nixpkgs nixpkgs-unstable;
   in {
     config = {
       # Required for homebrew and system.defaults options
       system.primaryUser = "yourusername";
       users.users.yourusername.home = "/Users/yourusername";

       nixpkgs.config.allowUnfree = true;

       # Enable Homebrew integration (optional - install homebrew first)
       homebrew = {
         enable = false;
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

       system.stateVersion = 5;
     };
   }
   ```

3. **Add to `flake-modules/darwin.nix`:**

   **Important**: The hostname must match your Mac's hostname!

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

4. Fix zsh files:

You may get an error about overwriting /etc/zshenv. Do this

    ```bash
      sudo mv /etc/zshenv /etc/zshenv.before-nix-darwin
    ```

5. **Build and apply:**
   ```bash
   # First time - bootstrap nix-darwin
   just build
   just switch

   # Subsequent updates
   just switch
   ```

---

## Booting the Test VM

The test VM lets you experiment with the flake without affecting your real system. It mounts this directory at `/tmp/shared` so you can edit files on your host and test changes inside the VM.

### On Linux

```bash
# First time (or after changes to VM config)
just run-test-vm

# If you need to start fresh
just clean-test-vm
just run-test-vm
```

### On macOS (M-series Macs)

The test VM runs as an aarch64-linux guest. You need Determinate Nix's native Linux builder.

> **Note**: As of 2026-01-14, this feature may not be enabled by default.
> See https://determinate.systems/blog/changelog-determinate-nix-384/
> Run `determinate-nixd --version` to check. If you see "The feature native-linux-builder is enabled" then this should work.

1. Add to `/etc/nix/nix.conf`:
   ```
   extra-experimental-features = external-builders
   ```

2. Restart the Nix daemon:
   ```bash
   sudo launchctl kickstart -k system/org.nixos.nix-daemon
   ```

3. Build and run:
   ```bash
   just build-test-vm
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
| `just build` | Build without switching |
| `just switch` | Build and apply configuration |
| `just build-test-vm` | Build the test VM |
| `just run-test-vm` | Build and run the test VM |
| `just clean-test-vm` | Remove VM disk and build artifacts |
| `just vm-switch <host>` | Switch inside VM (workaround for git worktrees) |
| `just deploy <host>` | Deploy to remote NixOS host via SSH |
| `just fmt` | Format all nix files |
| `just update` | Update flake inputs |
| `just repl` | Open nix repl with flake loaded |
| `just gc` | Garbage collect old generations |

---

## Next Steps

Once you're comfortable with the test VM:

1. **Add a real host**: Follow the "Adding New Hosts" section above
2. **Customize packages**: Edit `hosts/common/common-packages.nix`
3. **Set up secrets**: The flake includes [agenix](https://github.com/ryantm/agenix) for encrypted secrets
4. **Remote deployment**: Use `just deploy <hostname>` to deploy to remote NixOS machines
