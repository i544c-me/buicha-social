resource "aws_ecs_task_definition" "misskey" {
  family                   = "misskey"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  task_role_arn            = aws_iam_role.ecs_tasks.arn
  execution_role_arn       = aws_iam_role.ecs_tasks_execution.arn
  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "ghcr.io/i544c-me/buicha-social-misskey:2024.3.1-buiso.1"
      cpu       = 512
      memory    = 1280
      essential = true
      linuxParameters = {
        initProcessEnabled = true
      }
      portMappings = [
        {
          containerPort = 3000
        }
      ]
      mountPoints = [
        {
          containerPath = "/misskey/.config"
          sourceVolume  = aws_efs_file_system.misskey_config.name
        }
      ]
      #command = ["sleep", "3600"] # for debug
      environment = [
        { name = "MISSKEY_BLOCK_MENTIONS_FROM_UNFAMILIAR_REMOTE_USERS", value = "true" }, // スパム軽減
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/misskey/app"
          awslogs-region        = "ap-northeast-1"
          awslogs-stream-prefix = "misskey-app"
        }
      }
    },
  ])

  volume {
    name = aws_efs_file_system.misskey_config.name

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.misskey_config.id
      transit_encryption = "ENABLED"
    }
  }
}


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
