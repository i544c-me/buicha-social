locals {
  subnets = {
    public-1 = {
      availability_zone = "ap-northeast-1a"
      cidr_block        = "10.1.1.0/24"
      public            = true
    }
    public-2 = {
      availability_zone = "ap-northeast-1c"
      cidr_block        = "10.1.2.0/24"
      public            = true
    }
    private-1 = {
      availability_zone = "ap-northeast-1a"
      cidr_block        = "10.1.101.0/24"
      public            = false
    }
    private-2 = {
      availability_zone = "ap-northeast-1c"
      cidr_block        = "10.1.102.0/24"
      public            = false
    }

  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "${local.project}-main"
  }
}

resource "aws_subnet" "main" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = each.value.public

  tags = {
    Name = "${local.project}-${each.key}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project}-main"
  }
}

resource "aws_route_table" "main" {
  for_each = { for k, v in local.subnets : k => v if v.public == true }

  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.project}-${each.key}"
  }
}

resource "aws_route_table_association" "main" {
  for_each = { for k, v in local.subnets : k => v if v.public == true }

  subnet_id      = aws_subnet.main[each.key].id
  route_table_id = aws_route_table.main[each.key].id
}