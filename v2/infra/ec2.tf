data "aws_ssm_parameter" "amazon_linux_ami_id" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/arm64/recommended/image_id"
}

resource "aws_iam_role" "ecs_instance" {
  name = "${local.project}-ecs-instance"
  assume_role_policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

data "aws_iam_policy" "ecs_ec2_role" {
  name = "AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_ec2_role" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = data.aws_iam_policy.ecs_ec2_role.arn
}

resource "aws_iam_instance_profile" "main" {
  name = "${local.project}-main"
  role = aws_iam_role.ecs_instance.id
}

resource "aws_launch_template" "runner" {
  name                   = "${local.project}-runner"
  image_id               = data.aws_ssm_parameter.amazon_linux_ami_id.value
  instance_type          = "t4g.medium"
  vpc_security_group_ids = [aws_security_group.runner.id]
  user_data              = base64encode(replace(file("${path.module}/bin/init-ec2.sh"), "CLUSTER_NAME", aws_ecs_cluster.main.name))

  iam_instance_profile {
    name = aws_iam_instance_profile.main.id
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.project}-runner"
    }
  }
}

resource "aws_autoscaling_group" "runners" {
  name                = "${local.project}-runners"
  vpc_zone_identifier = [for k, v in local.subnets : aws_subnet.main[k].id if v.public]
  max_size            = 4
  min_size            = 1
  desired_capacity    = 1
  # TODO: ALB と連携
  #target_group_arns   = []

  launch_template {
    id      = aws_launch_template.runner.id
    version = aws_launch_template.runner.latest_version
  }
}


### EFS ###

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
  security_groups = [aws_security_group.misskey_config.id]
}

resource "aws_efs_access_point" "misskey_config" {
  file_system_id = aws_efs_file_system.misskey_config.id
  posix_user {
    gid = 991 # user  misskey
    uid = 991 # group misskey
  }
}


### Security Group ###

resource "aws_security_group" "runner" {
  name   = "${local.project}-runner"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project}-for-runner"
  }
}

resource "aws_security_group_rule" "for_runner_ingress" {
  security_group_id        = aws_security_group.runner.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "for_runner_egress" {
  security_group_id = aws_security_group.runner.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "misskey_config" {
  name   = "${local.project}-misskey-config"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project}-misskey-config"
  }
}

resource "aws_security_group_rule" "misskey_config_ingress" {
  security_group_id        = aws_security_group.misskey_config.id
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.runner.id
}
