resource "aws_db_subnet_group" "main" {
  name       = local.project
  subnet_ids = [for k, v in local.subnets : aws_subnet.main[k].id if !v.public]
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

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = ["412777285241/sg-038a1ad0f6f245c7b"]
  }

  tags = {
    Name = "${local.project}-rds"
  }
}

resource "aws_db_instance" "main" {
  allocated_storage           = 20
  identifier                  = local.project
  db_name                     = local.project
  engine                      = "postgres"
  engine_version              = "15.3"
  instance_class              = "db.t4g.large"
  username                    = var.rds_username
  password                    = var.rds_password
  db_subnet_group_name        = aws_db_subnet_group.main.id
  vpc_security_group_ids      = [aws_security_group.rds.id]
  parameter_group_name        = aws_db_parameter_group.default.id
  ca_cert_identifier          = "rds-ca-ecc384-g1"
  backup_retention_period     = 1
  backup_window               = "17:23-18:23"
  skip_final_snapshot         = true
  apply_immediately           = true
  allow_major_version_upgrade = true
  deletion_protection         = true
}

resource "aws_db_parameter_group" "default" {
  name   = "rds-pg"
  family = "postgres15"

  parameter {
    name  = "rds.force_ssl"
    value = 0
  }
}