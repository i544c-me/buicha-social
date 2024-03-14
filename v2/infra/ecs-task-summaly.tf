resource "aws_ecs_service" "summaly" {
  name                   = "${local.project}-summaly"
  cluster                = aws_ecs_cluster.main_v2.id
  task_definition        = aws_ecs_task_definition.summaly.arn
  desired_count          = 0
  enable_execute_command = true

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 150

  ordered_placement_strategy {
    type  = "binpack"
    field = "memory"
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main_v2.name
    base              = 1
    weight            = 100
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.main.arn
    service {
      client_alias {
        port = 3000
      }
      port_name = "summaly"
    }
    # TODO: デバッグ用、正常にアクセスできるようになったら設定を消すこと！
    log_configuration {
      log_driver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.service_connect_summaly.name
        awslogs-region        = "ap-northeast-1"
        awslogs-stream-prefix = "service-connect-summaly"
      }
    }
  }

  lifecycle {
    ignore_changes = [
      ## 無駄に replace が走らないようにするため
      ## ref: https://github.com/hashicorp/terraform-provider-aws/issues/22823
      #capacity_provider_strategy, # もしかしたら必要無いかも、ということでコメントにしてみる
      desired_count,
    ]
  }
}

resource "aws_ecs_task_definition" "summaly" {
  family                   = "summaly"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  task_role_arn            = aws_iam_role.ecs_tasks.arn
  execution_role_arn       = aws_iam_role.ecs_tasks_execution.arn
  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "ghcr.io/i544c-me/summaly:5.0.4-buiso.1"
      cpu       = 256
      memory    = 256
      essential = true
      linuxParameters = {
        initProcessEnabled = true
      }
      portMappings = [
        {
          name          = "summaly"
          appProtocol   = "http"
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

resource "aws_cloudwatch_log_group" "service_connect_summaly" {
  name              = "/ecs/service-connect-summaly"
  retention_in_days = 1 # TODO: 本番ではもっと長くする
}

resource "aws_cloudwatch_log_group" "misskey_summaly" {
  name              = "/ecs/misskey/summaly"
  retention_in_days = 1 # TODO: 本番ではもっと長くする
}
