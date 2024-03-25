resource "aws_lb" "meilisearch" {
  name               = "${local.project}-meilisearch"
  load_balancer_type = "application"
  subnets            = [for k, v in local.subnets : aws_subnet.main[k].id if v.public] # TODO: 本番稼働時はプライベートにする
  security_groups    = [aws_security_group.alb_for_meilisearch.id]

  idle_timeout = 300
}

resource "aws_lb_listener" "meilisearch" {
  load_balancer_arn = aws_lb.meilisearch.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.meilisearch.arn
  }
}

resource "aws_lb_target_group" "meilisearch" {
  name     = "${local.project}-meilisearch"
  vpc_id   = aws_vpc.main.id
  protocol = "HTTP"
  port     = 7700

  deregistration_delay = 5

  lifecycle {
    create_before_destroy = true
  }
}


### Security groups ###

resource "aws_security_group" "alb_for_meilisearch" {
  name   = "${local.project}-alb-for-meilisearch"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project}-alb-for-meilisearch"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_meilisearch_ingress" {
  security_group_id = aws_security_group.alb_for_meilisearch.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"

  # TODO: いずれ制限する
  #cidr_blocks       = [for k, v in local.subnets : aws_subnet.main[k].cidr_block if v.public]
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_meilisearch_egress" {
  security_group_id = aws_security_group.alb_for_meilisearch.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}
