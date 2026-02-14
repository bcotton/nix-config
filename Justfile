# Build the system config and switch to it when running `just` with no args
default: switch

hostname := `hostname | cut -d "." -f 1`

# Install git hooks (idempotent)
install-hooks:
    #!/usr/bin/env bash
    set -e
    current_path=$(git config --local core.hooksPath || echo "")
    if [ "$current_path" != ".githooks" ]; then
        echo "📌 Configuring git to use .githooks/"
        git config --local core.hooksPath .githooks
        echo "✓ Git hooks installed"
    fi

### macos
# Build the nix-darwin system configuration without switching to it
[macos]
build target_host=hostname flags="": install-hooks
  @echo "Building nix-darwin config..."
  nix --extra-experimental-features 'nix-command flakes'  build ".#darwinConfigurations.{{target_host}}.system" {{flags}}

# Build the nix-darwin config with the --show-trace flag set
[macos]
trace target_host=hostname: (build target_host "--show-trace")

# Build the nix-darwin configuration and switch to it
[macos]
switch target_host=hostname: (build target_host)
  @echo "switching to new config for {{target_host}}"
  sudo ./result/sw/bin/darwin-rebuild switch --flake ".#{{target_host}}"

### linux
# Build the NixOS configuration without switching to it
[linux]
build target_host=hostname flags="": install-hooks
  nix fmt .
  nixos-rebuild build --flake .#{{target_host}} {{flags}}

# Build the NixOS config with the --show-trace flag set
[linux]
trace target_host=hostname: (build target_host "--show-trace")

# Build the NixOS configuration and switch to it.
[linux]
switch target_host=hostname:
  sudo nixos-rebuild switch --flake .#{{target_host}}

# Build and dry-activate to show what would change without switching
[linux]
dry-activate target_host=hostname:
  sudo nixos-rebuild dry-activate --flake .#{{target_host}}

# Safely switch network configuration with automatic rollback
# This should be run ON the target host, not remotely
[linux]
safe-network-switch:
  @echo "⚠️  This command applies config and tests network connectivity"
  @echo "⚠️  It will automatically rollback if network tests fail"
  @echo ""
  @sudo ./scripts/safe-network-switch.sh

# Update flake inputs to their latest revisions
update:
  nix flake update

fmt: install-hooks
  nix fmt .

# Deploy to one or more remote NixOS hosts via SSH
# Usage: just deploy nas-01
#        just deploy nas-01 nix-01 nix-02
# Builds use distributed builders configured in the local host's nix-builder.coordinator
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

# Deploy to all NixOS hosts (excludes admin)
deploy-all:
  #!/usr/bin/env bash
  set -euo pipefail
  for host in $(nix eval --json '.#nixosConfigurations' --apply builtins.attrNames | jq -r '.[]' | grep -v admin); do
    echo "Deploying $host..."
    just deploy "$host" || echo "Failed to deploy $host"
  done

build-host hostname:
  nix build '.#nixosConfigurations.{{hostname}}.config.system.build.toplevel'

build-all:
  for i in `(nix flake show --json | jq -r '.nixosConfigurations |keys[]' | grep -v admin ) 2>/dev/null `; do echo $i; nix build ".#nixosConfigurations.$i.config.system.build.toplevel" || exit; done


vm:
  nix run '.#nixosConfigurations.nixos.config.system.build.nixos-shell'

repl:
  nix repl --expr "builtins.getFlake \"$PWD\""

# Garbage collect old OS generations and remove stale packages from the nix store
gc generations="5d":
  nix-env --delete-generations {{generations}}
  nix-store --gc

# Run nix flake check to validate all configurations
# Usage: just check              (pure mode, ZFS tests disabled)
#        just check --impure     (impure mode, enables ZFS tests)
check flags="":
  nix flake check {{flags}}

# Connect to nas-01 Supermicro IPMI console via SSH tunnel through admin host
nas-01-console:
  #!/usr/bin/env bash
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Opening SSH tunnel to nas-01 Supermicro IPMI console"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Port forward: localhost:8443 → 192.168.5.143:443"
  echo ""
  echo "Once connected, open in your browser:"
  echo "  https://localhost:8443"
  echo ""
  echo "Press Ctrl+C to close the tunnel"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  ssh -N -L 8443:192.168.5.143:443 admin

# List recent Forgejo CI runs
# Usage: just ci              (list recent runs)
#        just ci -s failure   (show only failures)
#        just ci show 401     (show run details)
#        just ci logs 401     (show run logs)
ci *args="":
  ./scripts/forgejo-runs.sh {{args}}

# Build an Incus VM image (qcow2 + metadata) for importing into Incus
build-incus-image host="incus-testing":
  #!/usr/bin/env bash
  set -euo pipefail
  echo "Building {{host}} qcow2 image..."
  nix build '.#nixosConfigurations.{{host}}.config.system.build.qemuImage' -o result-qemu-image
  echo "Building {{host}} metadata..."
  nix build '.#nixosConfigurations.{{host}}.config.system.build.metadata' -o result-metadata
  echo ""
  echo "Image artifacts:"
  ls -lh result-qemu-image/nixos.qcow2
  ls -lh result-metadata/tarball/
  echo ""
  echo "To import into Incus:"
  echo "  incus image import result-metadata/tarball/*.tar.xz result-qemu-image/nixos.qcow2 --alias nixos-{{host}}"
  echo ""
  echo "To launch:"
  echo "  incus launch nixos-{{host}} {{host}} --vm -c security.secureboot=false -c security.nesting=true -c limits.cpu=4 -c limits.memory=8GiB -d root,size=50GiB"

w-dconfdump:
  dconf dump / > tmp/w-dconf
w-dconf2nix:
  dconf2nix -i tmp/w-dconf -o tmp/w-dconf.nix
