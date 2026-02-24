# NixOS Upgrade Checklist

Things to check or re-evaluate when upgrading to the next NixOS release.

## smartctl_exporter v0.14.0 — DescribeByCollect race condition

**Affected host:** imac-01
**Disabled in:** `hosts/nixos/imac-01/default.nix`
**Upstream issue:** https://github.com/prometheus-community/smartctl_exporter/issues/305

The smartctl exporter is disabled on imac-01 because v0.14.0 has a race condition
in `DescribeByCollect` that causes HTTP 500 on every `/metrics` scrape when a device
returns non-zero exit codes (Apple SSD SM0256F returns exit status 4 on some ATA commands).

**On upgrade:** Check if nixpkgs ships a version newer than v0.14.0. If so, re-enable
by removing the `lib.mkForce false` override and restoring the device list and
`smartctl-enable` oneshot service from git history (commit `ca5607c`).

## mjpg-streamer replaced by ustreamer on octoprint

**Affected host:** octoprint
**Changed in:** `modules/octoprint/default.nix`

The nixpkgs mjpg-streamer package is pinned to a 2019 commit with a broken
`input_uvc.so` (undefined symbol `resolutions_help`). Replaced with ustreamer.

**On upgrade:** Check if nixpkgs has updated mjpg-streamer. If so, you could switch
back, but ustreamer is actively maintained and likely the better long-term choice.
No action needed unless ustreamer causes issues.
