# Build the system config and switch to it when running `just` with no args
default: switch

hostname := `hostname | cut -d "." -f 1`

### macos
# Build the nix-darwin system configuration without switching to it
[macos]
build target_host=hostname flags="":
  @echo "Building nix-darwin config..."
  nix --extra-experimental-features 'nix-command flakes'  build ".#darwinConfigurations.{{target_host}}.system" {{flags}}

# Build the nix-darwin config with the --show-trace flag set
[macos]
trace target_host=hostname: (build target_host "--show-trace")

# Build the nix-darwin configuration and switch to it
[macos]
switch target_host=hostname: (build target_host)
  @echo "switching to new config for {{target_host}}"
  ./result/sw/bin/darwin-rebuild switch --flake ".#{{target_host}}"

### linux
# Build the NixOS configuration without switching to it
[linux]
build target_host=hostname flags="":
  nix fmt
  nixos-rebuild build --flake .#{{target_host}} {{flags}}

# Build the NixOS config with the --show-trace flag set
[linux]
trace target_host=hostname: (build target_host "--show-trace")

# Build the NixOS configuration and switch to it.
[linux]
switch target_host=hostname:
  sudo nixos-rebuild switch --flake .#{{target_host}}

# Switch inside VM (workaround for git worktree issues with shared folders)
# Uses path: prefix to bypass git detection
[linux]
vm-switch target_host=hostname:
  sudo nixos-rebuild switch --flake "path:$(pwd)#{{target_host}}"

# Update flake inputs to their latest revisions
update:
  nix flake update

fmt:
  nix fmt .

# Deploy to one or more remote NixOS hosts via SSH
# Usage: just deploy nas-01
#        just deploy nas-01 nix-01 nix-02
deploy +hostnames:
  #!/usr/bin/env bash
  set -euo pipefail
  for hostname in {{hostnames}}; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Deploying $hostname..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    NIX_SSHOPTS="-A" nixos-rebuild switch --flake .#$hostname \
      --target-host root@$hostname || echo "⚠ Failed to deploy $hostname"
  done
  echo ""
  echo "✓ Deployment complete"

# Deploy to all NixOS hosts
deploy-all:
  #!/usr/bin/env bash
  set -euo pipefail
  for host in $(nix eval --json '.#nixosConfigurations' --apply builtins.attrNames | jq -r '.[]'); do
    echo "Deploying $host..."
    just deploy "$host" || echo "Failed to deploy $host"
  done

build-host hostname:
  nix build '.#nixosConfigurations.{{hostname}}.config.system.build.toplevel'

build-all:
  for i in `(nix flake show --json | jq -r '.nixosConfigurations |keys[]' | grep -v admin ) 2>/dev/null `; do echo $i; nix build ".#nixosConfigurations.$i.config.system.build.toplevel"; done
  
repl:
  nix repl --expr "builtins.getFlake \"$PWD\""

# Garbage collect old OS generations and remove stale packages from the nix store
gc generations="5d":
  nix-env --delete-generations {{generations}}
  nix-store --gc

# Build the test VM
[linux]
build-test-vm:
  nix build .#test-vm

# Run the test VM with shared folder mounting this directory to /mnt/flake
[linux]
run-test-vm:
  #!/usr/bin/env bash
  set -euo pipefail
  nix build .#test-vm
  SHARED_DIR="$(pwd)" ./result/bin/run-test-vm-vm

# Clean up test VM artifacts
[linux]
clean-test-vm:
  rm -f test-vm.qcow2 *.qcow2
  rm -rf result

# Build the test VM (aarch64-linux for M-series Macs)
[macos]
build-test-vm:
  nix build .#test-vm

# Run the test VM with shared folder mounting this directory to /mnt/flake
[macos]
run-test-vm:
  #!/usr/bin/env bash
  set -euo pipefail
  nix build .#test-vm
  SHARED_DIR="$(pwd)" ./result/bin/run-test-vm-vm

# Clean up test VM artifacts
[macos]
clean-test-vm:
  rm -f test-vm.qcow2 *.qcow2
  rm -rf result
