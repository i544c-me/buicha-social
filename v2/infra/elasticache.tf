#resource "aws_elasticache_subnet_group" "main" {
#  name       = "${local.project}-main"
#  subnet_ids = [for k, v in local.subnets : aws_subnet.main[k].id if !v.public]
#}
#
#resource "aws_security_group" "elasticache" {
#  name   = "${local.project}-elasticache"
#  vpc_id = aws_vpc.main.id
#
#  tags = {
#    Name = "${local.project}-elasticache"
#  }
#}
#
#resource "aws_security_group_rule" "elasticache_ingress" {
#  security_group_id        = aws_security_group.elasticache.id
#  type                     = "ingress"
#  from_port                = 6379
#  to_port                  = 6379
#  protocol                 = "tcp"
#  source_security_group_id = aws_security_group.runner.id
#}
#
#resource "aws_elasticache_cluster" "main" {
#  cluster_id               = "${local.project}-main"
#  engine                   = "redis"
#  node_type                = "cache.t3.micro"
#  num_cache_nodes          = 1
#  engine_version           = "7.1"
#  port                     = 6379
#  subnet_group_name        = aws_elasticache_subnet_group.main.name
#  security_group_ids       = [aws_security_group.elasticache.id]
#  snapshot_retention_limit = 1
#  snapshot_window          = "19:00-20:00"
#}
