resource "aws_codedeploy_app" "main" {
  name             = "${local.project}-main"
  compute_platform = "ECS"
}

resource "aws_codedeploy_deployment_group" "main_v2" {
  deployment_group_name = "${local.project}-main-v2"
  app_name              = aws_codedeploy_app.main.name
  service_role_arn      = aws_iam_role.codedeploy.arn

  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 2
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main_v2.name
    service_name = "buiso-v2-production-misskey-v5"
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.app_v4.arn]
      }

      target_group {
        name = aws_lb_target_group.app_v4["blue"].name
      }

      target_group {
        name = aws_lb_target_group.app_v4["green"].name
      }
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

resource "aws_iam_role" "codedeploy" {
  name = "${local.project}-codedeploy"
  assume_role_policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}
