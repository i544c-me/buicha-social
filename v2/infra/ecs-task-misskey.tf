### CloudWatch ###

resource "aws_cloudwatch_log_group" "misskey_app" {
  name              = "/ecs/misskey/app"
  retention_in_days = 1 # TODO: 本番ではもっと長くする
}


### AWS IAM ###

resource "aws_iam_role" "ecs_tasks" {
  name = "${local.project}-ecs-tasks"
  assume_role_policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_tasks" {
  name = "${local.project}-ecs-tasks"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
        ]
        Resource = ["*"]
      },
      // Misskey Config
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
        ]
        Resource = [
          aws_efs_file_system.misskey_config.arn,
        ]
        Condition = {
          StringEquals = {
            "elasticfilesystem:AccessPointArn" : aws_efs_access_point.misskey_config.arn,
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_tasks" {
  role       = aws_iam_role.ecs_tasks.name
  policy_arn = aws_iam_policy.ecs_tasks.arn
}


resource "aws_iam_role" "ecs_tasks_execution" {
  name = "${local.project}-ecs-tasks-execution"
  assume_role_policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_tasks_execution" {
  name = "${local.project}-ecs-tasks-execution"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_tasks_execution" {
  role       = aws_iam_role.ecs_tasks_execution.name
  policy_arn = aws_iam_policy.ecs_tasks_execution.arn
}
