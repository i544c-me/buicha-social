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

data "aws_iam_policy" "ssm_managed_instance_core" {
  name = "AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = data.aws_iam_policy.ssm_managed_instance_core.arn
}

resource "aws_iam_instance_profile" "main" {
  name = "${local.project}-main"
  role = aws_iam_role.ecs_instance.id
}

resource "aws_launch_template" "runner_v2_arm64" {
  name                   = "${local.project}-runner-v2"
  instance_type          = "t4g.medium"
  vpc_security_group_ids = [aws_security_group.runner.id]
  user_data              = base64encode(replace(file("${path.module}/bin/init-ec2.sh"), "CLUSTER_NAME", aws_ecs_cluster.main_v2.name))

  # With AMI name mentioned in the comments
  # amiFilter=[{"Name":"owner-alias","Values":["amazon"]},{"Name":"name","Values":["al2023-ami-ecs-hvm-*-arm64"]}]
  # currentImageName=al2023-ami-ecs-hvm-2023.0.20240730-kernel-6.1-arm64
  image_id = "ami-0e82876f0279700c6"

  iam_instance_profile {
    name = aws_iam_instance_profile.main.id
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.project}-runner-v2-arm64"
    }
  }
}

resource "aws_launch_template" "runner_v2_x86_64" {
  name                   = "${local.project}-runner-v2-intel"
  instance_type          = "t2.medium"
  vpc_security_group_ids = [aws_security_group.runner.id]
  user_data              = base64encode(replace(file("${path.module}/bin/init-ec2.sh"), "CLUSTER_NAME", aws_ecs_cluster.main_v2.name))

  # With AMI name mentioned in the comments
  # amiFilter=[{"Name":"owner-alias","Values":["amazon"]},{"Name":"name","Values":["al2023-ami-ecs-hvm-*-x86_64"]}]
  # currentImageName=al2023-ami-ecs-hvm-2023.0.20240802-kernel-6.1-x86_64
  image_id = "ami-072f0ffb9f5abdd87"

  iam_instance_profile {
    name = aws_iam_instance_profile.main.id
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.project}-runner-v2-x86_64"
    }
  }
}

resource "aws_autoscaling_group" "runners_v2" {
  name                  = "${local.project}-runners-v2"
  vpc_zone_identifier   = [for k, v in local.subnets : aws_subnet.main[k].id if v.public]
  max_size              = 6
  min_size              = 1
  desired_capacity      = 2
  desired_capacity_type = "units"

  # TODO: これを有効にするとキャパシティ低下を事前に予測できる
  # しかし m7g.medium が T2 Unlimited に対応していないとかでエラーになるので、それが解決できるまでは無効にしておく
  capacity_rebalance = true

  health_check_grace_period = 60

  # インスタンス置き換え時は可用性を優先する
  instance_maintenance_policy {
    min_healthy_percentage = 100
    max_healthy_percentage = 200
  }

  enabled_metrics = [
    "GroupAndWarmPoolDesiredCapacity",
    "GroupAndWarmPoolTotalCapacity",
    "GroupDesiredCapacity",
    "GroupInServiceCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingCapacity",
    "GroupPendingInstances",
    "GroupStandbyCapacity",
    "GroupStandbyInstances",
    "GroupTerminatingCapacity",
    "GroupTerminatingInstances",
    "GroupTotalCapacity",
    "GroupTotalInstances",
    "WarmPoolDesiredCapacity",
    "WarmPoolMinSize",
    "WarmPoolPendingCapacity",
    "WarmPoolTerminatingCapacity",
    "WarmPoolTotalCapacity",
    "WarmPoolWarmedCapacity",
  ]

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.runner_v2_arm64.id
        version            = aws_launch_template.runner_v2_arm64.latest_version
      }

      override {
        instance_type     = "t4g.medium"
        weighted_capacity = "3"
      }

      override {
        instance_type     = "t2.medium"
        weighted_capacity = "1"
        launch_template_specification {
          launch_template_id = aws_launch_template.runner_v2_x86_64.id
          version            = aws_launch_template.runner_v2_x86_64.latest_version
        }
      }
    }

    instances_distribution {
      on_demand_percentage_above_base_capacity = "0"
      on_demand_base_capacity                  = 1
      spot_allocation_strategy                 = "price-capacity-optimized"
      spot_instance_pools                      = 0
    }
  }

  # インスタンス更新を走らせる
  instance_refresh {
    strategy = "Rolling"
    triggers = ["tag"]
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

resource "aws_security_group_rule" "for_runner_ingress_alb" {
  for_each = toset([
    aws_security_group.alb_v4.id,
    aws_security_group.alb_for_summaly.id,
  ])

  security_group_id        = aws_security_group.runner.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = each.value
}

resource "aws_security_group_rule" "for_runner_egress" {
  security_group_id = aws_security_group.runner.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}
