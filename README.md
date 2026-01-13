# Nix Flake Starter

A multi-host, multi-platform Nix flake template for managing NixOS and macOS (nix-darwin) systems. Use this as a starting point for your own configuration.

## Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled
- [just](https://github.com/casey/just) command runner (optional but recommended)

## Quick Start

1. Clone this repository
2. Add your user (see below)
3. Boot the test VM to experiment
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
  home.stateVersion = "24.11";

  programs.git = {
    enable = true;
    userName = "Your Name";
    userEmail = "your@email.com";
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

### Step 3: Update flake.nix

Edit the `nixosConfigurations` section in `flake.nix` to use your username:

```nix
nixosConfigurations = {
  # Change ["bcotton"] to ["yourusername"]
  test-vm = nixosSystem "x86_64-linux" "test-vm" ["yourusername"];
};
```

### Step 4: Update the test-vm auto-login

Edit `hosts/nixos/test-vm/default.nix` and change the auto-login user:

```nix
services.getty.autologinUser = "yourusername";
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
sudo nixos-rebuild switch --flake .#test-vm
```

Or use the just command:

```bash
cd /tmp/shared
just switch test-vm
```

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
├── flake.nix                 # Main flake - defines all systems
├── flake.lock                # Locked dependency versions
├── Justfile                  # Build commands
│
├── hosts/
│   ├── common/
│   │   ├── common-packages.nix   # Packages for all systems
│   │   ├── nixos-common.nix      # NixOS-specific settings
│   │   └── darwin-common.nix     # macOS-specific settings
│   ├── nixos/
│   │   └── test-vm/              # Test VM configuration
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
| `just fmt` | Format all nix files |
| `just update` | Update flake inputs |
| `just repl` | Open nix repl with flake loaded |

---

## Next Steps

Once you're comfortable with the test VM:

1. **Add a real host**: Copy `hosts/nixos/test-vm/` to create a new host configuration
2. **Customize packages**: Edit `hosts/common/common-packages.nix`
3. **Add macOS support**: See `hosts/darwin/bobs-laptop/` for an example
4. **Set up secrets**: The flake includes [agenix](https://github.com/ryantm/agenix) for encrypted secrets
