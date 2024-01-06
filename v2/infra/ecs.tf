resource "aws_ecs_cluster" "main" {
  name = "${local.project}-main"
}

resource "aws_ecs_capacity_provider" "main" {
  name = "${local.project}-main"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.runners.arn
    managed_termination_protection = "DISABLED"

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
  desired_count          = 3
  enable_execute_command = true

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 150
  health_check_grace_period_seconds  = 60

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 3000
  }

  #depends_on = [
  #  aws_db_instance.main,
  #  aws_elasticache_cluster.main,
  #]

  lifecycle {
    ignore_changes = [
      # 無駄に replace が走らないようにするため
      # ref: https://github.com/hashicorp/terraform-provider-aws/issues/22823
      capacity_provider_strategy,
      desired_count,
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
      image     = "misskey/misskey:2023.12.2"
      cpu       = 512
      memory    = 1024
      essential = true
      linuxParameters = {
        initProcessEnabled = true
      }
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
  ])

  volume {
    name = aws_efs_file_system.misskey_config.name

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.misskey_config.id
      transit_encryption = "ENABLED"
    }
  }
}

resource "aws_appautoscaling_target" "ecs_target" {
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.misskey.name}"
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 3
  max_capacity       = 6
}

resource "aws_appautoscaling_policy" "ecs_policy" {
  name               = "target-tracking-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = "50"
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}


### CloudWatch ###

resource "aws_cloudwatch_log_group" "misskey_app" {
  name              = "/ecs/misskey/app"
  retention_in_days = 1 # TODO: 本番ではもっと長くする
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
        ]
        Condition = {
          StringEquals = {
            "elasticfilesystem:AccessPointArn" : aws_efs_access_point.misskey_config.arn,
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
