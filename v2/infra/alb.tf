resource "aws_lb" "app" {
  name               = "${local.project}-runners"
  load_balancer_type = "application"
  subnets            = [for k, v in local.subnets : aws_subnet.main[k].id if v.public]
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.alb.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_listener_rule" "robots" {
  listener_arn = aws_lb_listener.app.arn
  priority     = 110

  action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "User-agent: *\nDisallow: /"
      status_code  = "200"
    }
  }

  condition {
    path_pattern {
      values = ["/robots.txt"]
    }
  }

  tags = {
    Name = "robots"
  }
}

resource "aws_lb_listener_rule" "other_instances" {
  listener_arn = aws_lb_listener.app.arn
  priority     = 100

  action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Your instance is not allowed to connect me"
      status_code  = "403"
    }
  }

  condition {
    http_header {
      http_header_name = "user-agent"
      values           = ["*Misskey*", "*Mastodon*"]
    }
  }

  tags = {
    Name = "other-instances"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "${local.project}-app"
  vpc_id   = aws_vpc.main.id
  protocol = "HTTP"
  port     = 3000

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    interval            = 10
    timeout             = 5
  }

  lifecycle {
    create_before_destroy = true
  }
}


### Security group ###

resource "aws_security_group" "alb" {
  name   = "${local.project}-alb"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project}-alb"
  }
}

data "cloudflare_ip_ranges" "cloudflare" {}

resource "aws_security_group_rule" "alb_ingress" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks
}

resource "aws_security_group_rule" "alb_egress" {
  security_group_id = aws_security_group.alb.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # なぜか UDP で通信しているため
  cidr_blocks       = ["0.0.0.0/0"]
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
