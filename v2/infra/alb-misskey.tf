resource "aws_lb" "app_v4" {
  name               = "${local.project}-runners-v4"
  load_balancer_type = "application"

  ip_address_type = "dualstack-without-public-ipv4" # IPv6 only

  subnets = [for k, v in local.subnets : aws_subnet.main[k].id if v.public]
  security_groups = [
    aws_security_group.alb_v4.id,
    aws_security_group.alb_v6.id,
  ]

  idle_timeout = 4000 # Websocket の接続が切れる頻度を減らすため
}

resource "aws_lb_listener" "app_v4" {
  load_balancer_arn = aws_lb.app_v4.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.alb.arn

  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.app_v4["blue"].arn
      }
    }
  }

  lifecycle {
    # CodeDeploy による Blue/Green Deployment をしているため
    ignore_changes = [default_action[0].forward[0].target_group]
  }
}

resource "aws_lb_target_group" "app_v4" {
  for_each = toset(["blue", "green"])

  name     = "${local.project}-app-v4-${each.value}"
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

#resource "aws_lb_listener_rule" "admin" {
#  listener_arn = aws_lb_listener.app_v4.arn
#  priority     = 10
#  action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.app_v4["green"].arn
#  }
#  condition {
#    http_header {
#      http_header_name = "CF-Connecting-IP"
#      values           = var.admin_ips
#    }
#  }
#}
#
#resource "aws_lb_listener_rule" "maintenance" {
#  listener_arn = aws_lb_listener.app_v4.arn
#  priority     = 100
#
#  action {
#    type = "fixed-response"
#    fixed_response {
#      content_type = "text/html"
#      message_body = file("${path.module}/bin/error.html")
#      status_code  = "503"
#    }
#  }
#
#  condition {
#    path_pattern {
#      values = ["/*"]
#    }
#  }
#}


### Security group ###

data "cloudflare_ip_ranges" "cloudflare" {}

resource "aws_security_group" "alb_v4" {
  name   = "${local.project}-alb-v4"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project}-alb-v4"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_v4_egress" {
  security_group_id = aws_security_group.alb_v4.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # なぜか UDP で通信しているため
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "alb_v6" {
  name   = "${local.project}-alb-v6"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project}-alb-v6"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_v6_ingress" {
  security_group_id = aws_security_group.alb_v6.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  ipv6_cidr_blocks  = data.cloudflare_ip_ranges.cloudflare.ipv6_cidr_blocks
}


resource "aws_security_group_rule" "alb_v6_egress" {
  security_group_id = aws_security_group.alb_v6.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # なぜか UDP で通信しているため
  ipv6_cidr_blocks  = ["::/0"]
}


### ACM ###

resource "aws_acm_certificate" "alb" {
  domain_name       = local.main_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "alb" {
  certificate_arn         = aws_acm_certificate.alb.arn
  validation_record_fqdns = [for record in cloudflare_record.domain_cert_alb : record.hostname]
}
