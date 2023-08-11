data "cloudflare_ip_ranges" "cloudflare" {}

resource "aws_security_group" "alb_cloudflare" {
  name   = "${local.project}-alb-cloudflare"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [for ip in var.admin_ips : "${ip}/32"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.project}-alb-cloudflare"
  }
}
resource "aws_lb" "app" {
  name               = "${local.project}-app"
  load_balancer_type = "application"
  subnets            = [for k, v in local.subnets : aws_subnet.main[k].id if v.public]
  security_groups    = [aws_security_group.alb_cloudflare.id]
}

resource "aws_lb_target_group" "app" {
  name     = "${local.project}-app"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn

    ## Maintenance
    #type = "fixed-response"
    #fixed_response {
    #  content_type = "text/html"
    #  message_body = file("${path.module}/error_page/error.html")
    #  status_code  = "503"
    #}
  }
}

#resource "aws_lb_listener_rule" "maintenance" {
#  listener_arn = aws_lb_listener.app.arn
#  priority     = 100
#
#  action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.app.arn
#  }
#
#  condition {
#    http_header {
#      http_header_name = "CF-Connecting-IP"
#      values           = var.admin_ips
#    }
#  }
#}