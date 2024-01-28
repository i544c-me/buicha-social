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

resource "aws_launch_template" "runner_v2" {
  name                   = "${local.project}-runner-v2"
  image_id               = data.aws_ssm_parameter.amazon_linux_ami_id.value
  instance_type          = "t4g.medium"
  vpc_security_group_ids = [aws_security_group.runner.id]
  user_data              = base64encode(replace(file("${path.module}/bin/init-ec2.sh"), "CLUSTER_NAME", aws_ecs_cluster.main_v2.name))

  iam_instance_profile {
    name = aws_iam_instance_profile.main.id
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.project}-runner-v2"
    }
  }
}

resource "aws_autoscaling_group" "runners" {
  name                = "${local.project}-runners"
  vpc_zone_identifier = [for k, v in local.subnets : aws_subnet.main[k].id if v.public]
  max_size            = 0
  min_size            = 0
  desired_capacity    = 0

  launch_template {
    id      = aws_launch_template.runner.id
    version = aws_launch_template.runner.latest_version
  }

  lifecycle {
    ignore_changes = [
      desired_capacity,
    ]
  }
}

# ECS のキャパシティプロバイダが消せたらこれも消す
resource "aws_autoscaling_group" "tmp" {
  name                = "${local.project}-tmp"
  vpc_zone_identifier = [for k, v in local.subnets : aws_subnet.main[k].id if v.public]
  max_size            = 0
  min_size            = 0
  desired_capacity    = 0

  launch_template {
    id      = aws_launch_template.runner.id
    version = aws_launch_template.runner.latest_version
  }

  lifecycle {
    ignore_changes = [
      desired_capacity,
    ]
  }
}

resource "aws_autoscaling_group" "runners_v2" {
  name                = "${local.project}-runners-v2"
  vpc_zone_identifier = [for k, v in local.subnets : aws_subnet.main[k].id if v.public]
  max_size            = 6
  min_size            = 2
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.runner_v2.id
    version = aws_launch_template.runner_v2.latest_version
  }

  lifecycle {
    ignore_changes = [
      desired_capacity,
    ]
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }
}


### Security Group ###

resource "aws_security_group" "runner" {
  name   = "${local.project}-runner"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project}-for-runner"
  }

  lifecycle {
    create_before_destroy = true
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
