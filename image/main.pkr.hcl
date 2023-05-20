packer {
  required_plugins {
    amazon = {
      version = "= 1.1.6"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

locals {
  region   = "ap-northeast-1"
  project  = "buichasocial-ubuntu"
  date     = formatdate("YYYYMMDDHHmm", timestamp())
  ami_name = "${local.project}-${local.date}"
}

source "amazon-ebs" "ubuntu" {
  ami_name      = local.ami_name
  instance_type = "t2.medium"
  region        = local.region
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username          = "ubuntu"
  force_delete_snapshot = true
}

build {
  name = local.ami_name
  sources = [
    "source.amazon-ebs.ubuntu"
  ]
  provisioner "ansible" {
    playbook_file   = "./playbook.yml"
    use_proxy       = false
  }
}