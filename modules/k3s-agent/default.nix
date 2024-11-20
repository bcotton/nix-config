{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  services.k3s = {
    enable = true;
    role = "server";
    # tokenFile = /var/lib/rancher/k3s/server/token;
    token = "this is the random token";
    serverAddr =
      if config.networking.hostName == "k3s-01"
      then ""
      else "https://k3s-01:6443";
    extraFlags = toString [
      "--write-kubeconfig-mode \"0644\""
      "--cluster-init"
      "--disable servicelb"
      "--disable traefik"
      "--disable local-storage"
      "--flannel-iface enp2s0"
      "--flannel-backend=host-gw"
    ];
    clusterInit = config.networking.hostName == "k3s-01";
  };
}
