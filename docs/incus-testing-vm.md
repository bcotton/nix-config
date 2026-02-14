# Incus Testing VM

NixOS VM that runs inside the Incus cluster with nested Incus support and Tailscale access.

## Build the Image

```bash
just build-incus-image
```

This produces:
- `result-qemu-image/nixos.qcow2` - disk image
- `result-metadata/tarball/*.tar.xz` - Incus metadata

## Import and Launch

```bash
# Import
incus image import result-metadata/tarball/*.tar.xz result-qemu-image/nixos.qcow2 \
  --alias nixos-incus-testing

# Launch
incus launch nixos-incus-testing incus-testing --vm \
  -c security.secureboot=false \
  -c security.nesting=true \
  -c limits.cpu=4 \
  -c limits.memory=8GiB \
  -d root,size=50GiB
```

Flags:
- `security.secureboot=false` - NixOS images aren't signed for secure boot
- `security.nesting=true` - required for running Incus inside the VM
- Root disk should be >= 50GiB for nested container images

## First Boot Setup

agenix secrets won't decrypt on first boot because the VM's host key isn't registered yet.

```bash
# 1. Get a shell
incus exec incus-testing -- bash

# 2. Set up Tailscale manually
tailscale up

# 3. Get the host SSH key
cat /etc/ssh/ssh_host_ed25519_key.pub
```

Then on your workstation:

```bash
# 4. Add the key to secrets/secrets.nix:
#    incus-testing = "ssh-ed25519 AAAA... root@incus-testing";
#    Add incus-testing to the 'systems' list

# 5. Re-encrypt all secrets
agenix -r

# 6. Deploy full config (now with working secrets)
just deploy incus-testing
```

## Enable KVM for Nested VMs

To run VMs (not just containers) inside the incus-testing VM, pass through `/dev/kvm`:

```bash
incus config device add incus-testing kvm unix-char source=/dev/kvm
incus restart incus-testing
```

## Subsequent Updates

```bash
just deploy incus-testing
```

## Using Incus Inside the VM

The VM comes preconfigured with:
- `dir` storage pool (default)
- NAT bridge `incusbr0` (10.0.100.0/24)
- Default profile connecting to both

```bash
incus launch images:alpine/3.20 test-container
incus launch images:alpine/3.20 test-vm --vm  # requires KVM passthrough
```
