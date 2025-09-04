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
  sudo ./result/sw/bin/darwin-rebuild switch --flake ".#{{target_host}}"

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

# Update flake inputs to their latest revisions
update:
  nix flake update

fmt:
  nix fmt

  # Run nixinate for a specific host
nixinate hostname:
  nix run ".#apps.nixinate.{{hostname}}"

build-host hostname:
  nix build '.#nixosConfigurations.{{hostname}}.config.system.build.toplevel'

nix-all:
  for i in `(nix flake show --json | jq -r '.nixosConfigurations |keys[]' | grep -v admin ) 2>/dev/null `; do nix run ".#apps.nixinate.$i" ; done

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

check:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Create temporary file
    temp_file=$(mktemp)
    trap 'rm -f "$temp_file"' EXIT
    
    # Copy original file and comment out nixinate
    sed 's/^    apps.nixinate/    # apps.nixinate/' flake.nix > "$temp_file"
    
    # Backup original and move temp file into place
    cp flake.nix flake.nix.bak
    mv "$temp_file" flake.nix
    
    # Run check and store result
    if nix flake check; then
        check_status=$?
        mv flake.nix.bak flake.nix
        exit $check_status
    else
        check_status=$?
        mv flake.nix.bak flake.nix
        exit $check_status
    fi
