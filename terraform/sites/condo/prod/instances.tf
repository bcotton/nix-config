# Home Assistant OS instance with bridged networking
resource "incus_instance" "homeassistant" {
  name      = "${var.environment}-homeassistant"
  image     = incus_image.haos.fingerprint
  type      = "virtual-machine"
  profiles  = [module.profiles.haos_profile_name]
  project   = "default"

  config = {
    "migration.stateful" = "false"
  }

  depends_on = [incus_image.haos]

  device {
    name = "eth0"
    type = "nic"

    properties = {
      nictype = "bridged"
      parent  = var.network_bridge
      # hwaddr = "00:23:24:ae:eb:f1"
    }
  }

  device {
    name = "root"
    type = "disk"

    properties = {
      pool = var.storage_pool
      path = "/"
      size = var.storage_sizes["vm"]
    }
  }
  device {
    name = "usb"
    type = "usb"
    
    properties = {
      vendorid  = "10c4"
      productid = "ea60"
    }
  }
}
