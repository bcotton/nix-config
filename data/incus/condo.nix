# Condo site instance definitions
# Controller host: condo-01 (single host, not clustered)
# NOTE: Deploy only when physically present at site
{
  # Home Assistant OS VM with Zigbee USB stick
  # Image must be pre-imported: cd terraform/images/haos && ./run.sh --import
  prod-homeassistant = {
    type = "vm";
    deploy = "opaque";
    profile = "haos";
    imageAlias = "haos";
    storagePool = "local";
    network = {
      mode = "bridged";
      parent = "br0";
    };
    devices = {
      usb = {
        type = "usb";
        properties = {
          vendorid = "10c4";
          productid = "ea60";
        };
      };
    };
    extraConfig = {
      "migration.stateful" = "false";
      "boot.autostart" = "true";
    };
  };
}
