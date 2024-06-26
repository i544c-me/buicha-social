resource "aws_ecs_service" "summaly" {
  name                   = "${local.project}-summaly"
  cluster                = aws_ecs_cluster.main_v2.id
  task_definition        = aws_ecs_task_definition.summaly.arn
  desired_count          = 2
  enable_execute_command = true

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 150
  health_check_grace_period_seconds  = 60

  ordered_placement_strategy {
    type  = "binpack"
    field = "memory"
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main_v2.name
    base              = 1
    weight            = 100
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.summaly.arn
    container_name   = "app"
    container_port   = 3000
  }
}

resource "aws_ecs_task_definition" "summaly" {
  family                   = "summaly"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  task_role_arn            = aws_iam_role.ecs_tasks.arn
  execution_role_arn       = aws_iam_role.ecs_tasks_execution.arn
  cpu                      = 256
  memory                   = 256
  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "ghcr.io/i544c-me/summaly:v5.1.0-buiso.1"
      cpu       = 256
      memory    = 256
      essential = true
      linuxParameters = {
        initProcessEnabled = true
      }
      portMappings = [
        {
          containerPort = 3000
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.misskey_summaly.name
          awslogs-region        = "ap-northeast-1"
          awslogs-stream-prefix = "misskey-summaly"
        }
      }
    },
  ])
}


### CloudWatch ###

resource "aws_cloudwatch_log_group" "misskey_summaly" {
  name              = "/ecs/misskey/summaly"
  retention_in_days = 1 # TODO: 本番ではもっと長くする
}
