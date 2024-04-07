resource "aws_lb" "summaly" {
  name               = "${local.project}-summaly"
  load_balancer_type = "application"
  subnets            = [for k, v in local.subnets : aws_subnet.main[k].id if !v.public]
  security_groups    = [aws_security_group.alb_for_summaly.id]
  internal           = true

  idle_timeout = 300
}

resource "aws_lb_listener" "summaly" {
  load_balancer_arn = aws_lb.summaly.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.summaly.arn
  }
}

resource "aws_lb_target_group" "summaly" {
  name     = "${local.project}-summaly"
  vpc_id   = aws_vpc.main.id
  protocol = "HTTP"
  port     = 3000

  deregistration_delay = 5

  health_check {
    matcher             = "400"
    healthy_threshold   = 3
    unhealthy_threshold = 2
    interval            = 90
    timeout             = 60
  }

  lifecycle {
    create_before_destroy = true
  }
}


### Security groups ###

resource "aws_security_group" "alb_for_summaly" {
  name   = "${local.project}-alb-for-summaly"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project}-alb-for-summaly"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_summaly_ingress" {
  security_group_id = aws_security_group.alb_for_summaly.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [for k, v in local.subnets : aws_subnet.main[k].cidr_block if v.public]
}

resource "aws_security_group_rule" "alb_summaly_egress" {
  security_group_id = aws_security_group.alb_for_summaly.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}
