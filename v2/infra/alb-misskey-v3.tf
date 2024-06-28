resource "aws_lb" "app_v3" {
  name               = "${local.project}-runners-v3"
  load_balancer_type = "application"

  ip_address_type = "dualstack-without-public-ipv4" # IPv6 only

  subnets = [for k, v in local.subnets : aws_subnet.main[k].id if v.public]
  security_groups = [
    aws_security_group.alb_v4.id,
    aws_security_group.alb_v6.id,
  ]

  idle_timeout = 4000 # Websocket の接続が切れる頻度を減らすため
}

resource "aws_lb_listener" "app_v3" {
  load_balancer_arn = aws_lb.app_v3.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.alb.arn

  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.app_v3["blue"].arn
      }
    }
  }

  lifecycle {
    # CodeDeploy による Blue/Green Deployment をしているため
    ignore_changes = [default_action[0].forward[0].target_group]
  }
}

resource "aws_lb_target_group" "app_v3" {
  for_each = toset(["blue", "green"])

  name     = "${local.project}-app-v3-${each.value}"
  vpc_id   = aws_vpc.main.id
  protocol = "HTTP"
  port     = 3000

  deregistration_delay = 10 # 接続断のタイムアウトがデフォルト300秒だと長いので
  slow_start           = 30

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 10
    interval            = 20
    timeout             = 10
  }

  lifecycle {
    create_before_destroy = true
  }
}
