locals {
  min_tasks = 3
  max_tasks = 12
}

resource "aws_ecs_cluster" "main_v2" {
  name = "${local.project}-main-v2"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    "AWS.SSM.AppManager.ECS.Cluster.ARN" = "arn:aws:ecs:ap-northeast-1:${local.account_id}:cluster/${local.project}-main-v2"
  }
}


resource "aws_ecs_capacity_provider" "main_v2" {
  name = "${local.project}-main-v2"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.runners_v2.arn
    managed_termination_protection = "DISABLED"
    managed_draining               = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 1000
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main_v2" {
  cluster_name       = aws_ecs_cluster.main_v2.name
  capacity_providers = [aws_ecs_capacity_provider.main_v2.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.main_v2.name
  }
}

resource "aws_ecs_service" "misskey_v3" {
  name                   = "${local.project}-misskey-v3"
  cluster                = aws_ecs_cluster.main_v2.id
  task_definition        = aws_ecs_task_definition.misskey.arn
  desired_count          = local.min_tasks
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
      ## 無駄に replace が走らないようにするため
      ## ref: https://github.com/hashicorp/terraform-provider-aws/issues/22823
      #capacity_provider_strategy, # もしかしたら必要無いかも、ということでコメントにしてみる
      desired_count,
    ]
  }
}

resource "aws_appautoscaling_target" "ecs_target_v3" {
  resource_id        = "service/${aws_ecs_cluster.main_v2.name}/${aws_ecs_service.misskey_v3.name}"
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = local.min_tasks
  max_capacity       = local.max_tasks
}

resource "aws_appautoscaling_policy" "ecs_policy_v3" {
  name               = "target-tracking-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target_v3.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target_v3.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target_v3.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = "50"
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}