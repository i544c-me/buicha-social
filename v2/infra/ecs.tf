resource "aws_ecs_cluster" "main" {
  name = "${local.project}-main"
}

resource "aws_ecs_capacity_provider" "main" {
  name = "${local.project}-main"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.runners.arn
    managed_termination_protection = "DISABLED" # TODO: これなんだっけ

    managed_scaling {
      maximum_scaling_step_size = 1000
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.main.name
  }
}

resource "aws_ecs_service" "misskey" {
  name                   = "${local.project}-misskey"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.misskey.arn
  desired_count          = 1
  enable_execute_command = true

  ordered_placement_strategy {
    type  = "binpack"
    field = "memory"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 3000
  }

  depends_on = [
    aws_db_instance.main,
    aws_elasticache_cluster.main,
  ]

  # 無駄に replace が走らないようにするため
  # ref: https://github.com/hashicorp/terraform-provider-aws/issues/22823
  lifecycle {
    ignore_changes = [
      capacity_provider_strategy
    ]
  }
}

resource "aws_ecs_task_definition" "misskey" {
  family                   = "misskey"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  task_role_arn            = aws_iam_role.ecs_tasks.arn
  execution_role_arn       = aws_iam_role.ecs_tasks_execution.arn
  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "ghcr.io/i544c-me/buicha-social-misskey:2023.9.3-buiso.2"
      cpu       = 256
      memory    = 1024
      essential = false # TODO: あとでtrueにする
      linuxParameters = {
        initProcessEnabled = true
      }
      links = ["squid"]
      portMappings = [
        {
          containerPort = 3000
        }
      ]
      mountPoints = [
        {
          containerPath = "/misskey/.config"
          sourceVolume  = aws_efs_file_system.misskey_config.name
        }
      ]
      #command = ["sleep", "3600"] # for debug
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/misskey/app"
          awslogs-region        = "ap-northeast-1"
          awslogs-stream-prefix = "misskey-app"
        }
      }
    },
    {
      name      = "squid"
      image     = "ubuntu/squid:5.2-22.04_beta"
      cpu       = 128
      memory    = 128
      essential = true
      linuxParameters = {
        initProcessEnabled = true
      }
      mountPoints = [
        {
          containerPath = "/etc/squid"
          sourceVolume  = aws_efs_file_system.squid_config.name
        }
      ]
    }
  ])

  volume {
    name = aws_efs_file_system.misskey_config.name

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.misskey_config.id
      transit_encryption = "ENABLED"
    }
  }

  volume {
    name = aws_efs_file_system.squid_config.name

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.squid_config.id
      transit_encryption = "ENABLED"
    }
  }
}


### CloudWatch ###

resource "aws_cloudwatch_log_group" "misskey_app" {
  name              = "/ecs/misskey/app"
  retention_in_days = 1
}


### AWS IAM ###

resource "aws_iam_role" "ecs_tasks" {
  name = "${local.project}-ecs-tasks"
  assume_role_policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_tasks" {
  name = "${local.project}-ecs-tasks"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
        ]
        Resource = [
          aws_efs_file_system.misskey_config.arn,
          aws_efs_file_system.squid_config.arn,
        ]
        Condition = {
          StringEquals = {
            "elasticfilesystem:AccessPointArn" : aws_efs_access_point.misskey_config.arn,
            "elasticfilesystem:AccessPointArn" : aws_efs_access_point.squid_config.arn,
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_tasks" {
  role       = aws_iam_role.ecs_tasks.name
  policy_arn = aws_iam_policy.ecs_tasks.arn
}


resource "aws_iam_role" "ecs_tasks_execution" {
  name = "${local.project}-ecs-tasks-execution"
  assume_role_policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_tasks_execution" {
  name = "${local.project}-ecs-tasks-execution"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_tasks_execution" {
  role       = aws_iam_role.ecs_tasks_execution.name
  policy_arn = aws_iam_policy.ecs_tasks_execution.arn
}
