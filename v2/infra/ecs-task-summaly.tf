### CloudWatch ###

resource "aws_cloudwatch_log_group" "misskey_summaly" {
  name              = "/ecs/misskey/summaly"
  retention_in_days = 1 # TODO: 本番ではもっと長くする
}
