### Misskey Config ###

resource "aws_efs_file_system" "misskey_config" {
  creation_token = "${local.project}-misskey-config"
  encrypted      = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "${local.project}-misskey-config"
  }
}

resource "aws_efs_mount_target" "misskey_config" {
  for_each = { for k, v in local.subnets : k => v if v.public }

  file_system_id  = aws_efs_file_system.misskey_config.id
  subnet_id       = aws_subnet.main[each.key].id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_access_point" "misskey_config" {
  file_system_id = aws_efs_file_system.misskey_config.id

  posix_user {
    gid = 991 # user  misskey
    uid = 991 # group misskey
  }
}


### Security Group ###

resource "aws_security_group" "efs" {
  name   = "${local.project}-efs"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project}-efs"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "efs_ingress" {
  security_group_id        = aws_security_group.efs.id
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.runner.id
}
