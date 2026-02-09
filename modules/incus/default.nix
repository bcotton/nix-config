{
  config,
  pkgs,
  ...
}: {
  networking.nftables.enable = true;
  networking.firewall.allowedTCPPorts = [8443];

  virtualisation.incus.enable = true;
  virtualisation.incus.package = pkgs.incus;
  virtualisation.incus.ui.enable = true;

  virtualisation.incus.preseed = {};
  # virtualisation.incus.preseed = {
  #   config = {"core.https_address" = "192.168.5.213:8443";};
  #   networks = [];
  #   storage_pools = [
  #     {
  #       config = {size = "30GiB";};
  #       description = "";
  #       name = "local";
  #       driver = "btrfs";
  #     }
  #   ];
  #   profiles = [
  #     {
  #       config = {};
  #       description = "";
  #       devices = {
  #         root = {
  #           path = "/";
  #           pool = "local";
  #           type = "disk";
  #         };
  #       };
  #       name = "default";
  #     }
  #   ];
  #   projects = [];
  #   cluster = {
  #     # server_name = "nix-02";
  #     server_name = "${config.networking.hostName}";
  #     enabled = true;
  #     member_config = [];
  #     cluster_address = "";
  #     cluster_certificate = "";
  #     server_address = "";
  #     cluster_token = "";
  #     cluster_certificate_path = "";
  #   };
  # };
}
