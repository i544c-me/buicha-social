variable "app_count" {
  default = 2
}

resource "sakuracloud_switch" "main" {
  name = "main"
  tags = ["misskey"]
}

resource "sakuracloud_vpc_router" "main" {
  name                = "main"
  tags                = ["misskey"]
  internet_connection = true
  plan                = "standard"

  private_network_interface {
    index        = 1
    ip_addresses = ["192.168.1.254"]
    netmask      = "24"
    switch_id    = sakuracloud_switch.main.id
  }
}

resource "sakuracloud_server" "app" {
  count = var.app_count
  name  = "app-${count.index + 1}"
  tags  = ["misskey", "app"]

  core   = 1
  memory = 1
  disks  = [sakuracloud_disk.app[count.index].id]

  network_interface {
    upstream        = sakuracloud_switch.main.id
    user_ip_address = "192.168.1.${count.index + 1}"
  }

  disk_edit_parameter {
    hostname        = "app-${count.index + 1}"
    disable_pw_auth = true
    ip_address      = "192.168.1.${count.index + 1}"
    netmask         = 24
    gateway         = "192.168.1.254"
  }
}

data "sakuracloud_archive" "ubuntu" {
  os_type = "ubuntu2204"
}

resource "sakuracloud_disk" "app" {
  count             = var.app_count
  name              = "app-${count.index + 1}"
  source_archive_id = data.sakuracloud_archive.ubuntu.id
}
