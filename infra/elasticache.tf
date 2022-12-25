resource "aws_elasticache_subnet_group" "main" {
  name       = "${local.project}-main"
  subnet_ids = [for k, v in local.subnets : aws_subnet.main[k].id if v.public == false]
}

resource "aws_security_group" "elasticache" {
  name   = "elasticache"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  tags = {
    Name = "${local.project}-elasticache"
  }
}

resource "aws_elasticache_cluster" "main" {
  cluster_id         = "${local.project}-main"
  engine             = "redis"
  node_type          = "cache.t3.micro"
  num_cache_nodes    = 1
  engine_version     = "7.0"
  port               = 6379
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.elasticache.id]
}