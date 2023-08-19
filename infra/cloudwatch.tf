resource "aws_cloudwatch_log_group" "misskey_output" {
  name = "misskey_output"
  retention_in_days = 7

  tags = {
    Name = "${local.project}-log-output"
  }
}

resource "aws_cloudwatch_log_group" "misskey_error" {
  name = "misskey_error"
  retention_in_days = 7

  tags = {
    Name = "${local.project}-log-error"
  }
}

resource "aws_s3_bucket" "synthetics_canary" {
  bucket = "${local.project}-synthetics-canary"
}

resource "aws_iam_role" "synthetics_canary" {
  name = "${local.project}-synthetics-canary"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "synthetics_canary" {
  name = "${local.project}-synthetics-canary"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:GetObject"
        ],
        "Resource" : [
          "${aws_s3_bucket.synthetics_canary.arn}/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:GetBucketLocation"
        ],
        "Resource" : [
          aws_s3_bucket.synthetics_canary.arn
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ],
        "Resource" : [
          "arn:aws:logs:ap-northeast-1:${local.account_id}:*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:ListAllMyBuckets",
          "xray:PutTraceSegments"
        ],
        "Resource" : [
          "*"
        ]
      },
      {
        "Effect" : "Allow",
        "Resource" : "*",
        "Action" : "cloudwatch:PutMetricData",
        "Condition" : {
          "StringEquals" : {
            "cloudwatch:namespace" : "CloudWatchSynthetics"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "syntetics_canary" {
  role       = aws_iam_role.synthetics_canary.name
  policy_arn = aws_iam_policy.synthetics_canary.arn
}

resource "aws_synthetics_canary" "app" {
  name                 = "${local.project}-app"
  artifact_s3_location = "s3://${aws_s3_bucket.synthetics_canary.id}/"
  s3_bucket            = aws_s3_bucket.synthetics_canary.bucket
  s3_key               = "cwsyn-tmp-buicha-social-de23de9b-86a4-459d-a3c0-49f290f21d8a-996de482-b9a9-4001-bbea-d1fafb0025bf.zip"
  execution_role_arn   = aws_iam_role.synthetics_canary.arn
  handler              = "pageLoadBlueprint.handler"
  runtime_version      = "syn-nodejs-puppeteer-3.9"
  delete_lambda        = true
  start_canary         = true

  schedule {
    expression = "rate(5 minutes)"
  }
}