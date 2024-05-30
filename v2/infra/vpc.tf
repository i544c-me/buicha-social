locals {
  subnets = {
    public-1 = {
      availability_zone = "ap-northeast-1a"
      cidr_block        = "10.10.1.0/24"
      public            = true
    }
    public-2 = {
      availability_zone = "ap-northeast-1c"
      cidr_block        = "10.10.2.0/24"
      public            = true
    }
    public-3 = {
      availability_zone = "ap-northeast-1d"
      cidr_block        = "10.10.3.0/24"
      public            = true
    }
    private-1 = {
      availability_zone = "ap-northeast-1a"
      cidr_block        = "10.10.101.0/24"
      public            = false
    }
    private-2 = {
      availability_zone = "ap-northeast-1c"
      cidr_block        = "10.10.102.0/24"
      public            = false
    }
    private-3 = {
      availability_zone = "ap-northeast-1d"
      cidr_block        = "10.10.103.0/24"
      public            = false
    }
  }
  subnets_index = [for k, v in local.subnets : k]
}

resource "aws_vpc" "main" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true

  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "${local.project}-main"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_subnet" "main" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr_block
  ipv6_cidr_block         = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, index(local.subnets_index, each.key))
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = each.value.public # TODO: 一律に IPv4 を付与するのはやめる

  enable_dns64                    = true
  assign_ipv6_address_on_creation = false # セキュリティ上の懸念から、一律には IPv6 は付与しない

  tags = {
    Name = "${local.project}-${each.key}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project}-main"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route_table" "main" {
  for_each = { for k, v in local.subnets : k => v if v.public }

  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  # 旧インフラに接続するため
  route {
    cidr_block                = "10.1.0.0/16"
    vpc_peering_connection_id = "pcx-03918bff9f49059d7"
  }

  tags = {
    Name = "${local.project}-${each.key}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route_table_association" "main" {
  for_each = { for k, v in local.subnets : k => v if v.public }

  subnet_id      = aws_subnet.main[each.key].id
  route_table_id = aws_route_table.main[each.key].id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_peering_connection" "old_infra" {
  vpc_id        = aws_vpc.main.id
  peer_owner_id = "234031622584"
  peer_vpc_id   = "vpc-04a18a5882cdb596e"

  tags = {
    Name = "${local.project}-old-infra"
  }
}
