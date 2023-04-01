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
  execution_role_arn   = aws_iam_role.synthetics_canary.arn
  handler              = "pageLoadBlueprint.handler"
  runtime_version      = "syn-nodejs-puppeteer-3.9"

  schedule {
    expression = "rate(5 minutes)"
  }
}