resource "aws_db_subnet_group" "main" {
  name       = local.project
  subnet_ids = [for k, v in local.subnets : aws_subnet.main[k].id if v.public == false]
}

resource "aws_security_group" "rds" {
  name   = "rds"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  tags = {
    Name = "${local.project}-rds"
  }
}

resource "aws_db_instance" "main" {
  allocated_storage      = 20
  identifier             = local.project
  db_name                = local.project
  engine                 = "postgres"
  engine_version         = "13.7"
  instance_class         = "db.t3.micro"
  username               = var.rds_username
  password               = var.rds_password
  db_subnet_group_name   = aws_db_subnet_group.main.id
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
}