# FreshRSS - Incus container on clubcotton cluster
# Dependencies: PostgreSQL on nas-01 (network access to nas-01.lan:5432)
# Secrets: freshrss.age, freshrss-database-raw.age (encrypted via agenix)
#
# First-time setup:
# 1. Launch container via incus-cluster controller
# 2. Get host key: incus exec freshrss -- cat /etc/ssh/ssh_host_ed25519_key.pub
# 3. Add to secrets/secrets.nix systems list
# 4. Re-encrypt: cd secrets && agenix -r
# 5. Rebuild container image and relaunch
{
  config,
  pkgs,
  lib,
  hostName,
  ...
}: let
  commonLib = import ../../common/lib.nix;
  variables = commonLib.getHostVariables hostName;
in {
  imports = [
    ./hardware-configuration.nix
  ];

  networking = {
    hostName = "freshrss";
    # DHCP via systemd-networkd (lxc-container.nix configures veth DHCP)
    useDHCP = true;
    # Use nftables (required for Incus compatibility)
    nftables.enable = true;
    firewall.enable = true;
    # Container gets DNS from DHCP, not host resolv.conf
    useHostResolvConf = false;
  };

  # FreshRSS service
  services.clubcotton.freshrss = {
    enable = true;
    port = 8104;
    passwordFile = config.age.secrets."freshrss".path;
    authType = "form";
    extensions = with pkgs.freshrss-extensions; [youtube];
    tailnetHostname = "freshrss";
  };

  # Enable SSH for management (agenix key retrieval, debugging)
  services.openssh.enable = true;

  system.stateVersion = variables.stateVersion;
}
