data "aws_ami" "ubuntu" {
  owners      = ["self"]
  most_recent = true

  filter {
    name   = "name"
    values = ["buichasocial-ubuntu-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "app" {
  name   = "app_server"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.project}-app"
  }
}

resource "aws_launch_template" "app" {
  name = "${local.project}-app"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.id
  }

  image_id               = data.aws_ami.ubuntu.id
  instance_type          = "t2.small"
  vpc_security_group_ids = [aws_security_group.app.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.project}-app"
    }
  }
}

resource "aws_instance" "temp_for_upgrade" {
  subnet_id = [for k, v in local.subnets : aws_subnet.main[k].id if v.public][0]
  ami = "ami-0014b861bc680eb9a" # buichasocial-ubuntu-202306100812

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${local.project}-app"
  vpc_zone_identifier = [for k, v in local.subnets : aws_subnet.main[k].id if v.public]
  max_size            = 3
  min_size            = 1
  desired_capacity    = 1
  target_group_arns   = [aws_lb_target_group.app.arn]
  enabled_metrics = [
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }
}

resource "aws_autoscaling_policy" "app" {
  name                   = "${local.project}-app"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}

### SSM ###

resource "aws_iam_role" "ec2" {
  name = "${local.project}-ec2"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

data "aws_iam_policy" "ssm_managed_instance_core" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2" {
  role       = aws_iam_role.ec2.name
  policy_arn = data.aws_iam_policy.ssm_managed_instance_core.arn
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.project}-ec2"
  role = aws_iam_role.ec2.name
}
