resource "aws_cloudwatch_log_group" "misskey_output" {
  name              = "misskey_output"
  retention_in_days = 7

  tags = {
    Name = "${local.project}-log-output"
  }
}

resource "aws_cloudwatch_log_group" "misskey_error" {
  name              = "misskey_error"
  retention_in_days = 7

  tags = {
    Name = "${local.project}-log-error"
  }
}

resource "aws_s3_bucket" "synthetics_canary" {
  bucket = "${local.project}-synthetics-canary"
  force_destroy = true
}