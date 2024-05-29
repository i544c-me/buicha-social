terraform {
  required_version = "1.8.1"

  required_providers {
    sakuracloud = {
      source  = "sacloud/sakuracloud"
      version = "2.25.3"
    }
  }
}

provider "sakuracloud" {
}