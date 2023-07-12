# TODO: 次のマネージドルールを有効化する
#   - AWS-AWSManagedRulesKnownBadInputsRuleSet
#   - AWS-AWSManagedRulesSQLiRuleSet
#   - AWS-AWSManagedRulesLinuxRuleSet

resource "aws_wafv2_web_acl" "app" {
  provider    = aws.us_east_1
  name        = "${local.project}-app-rule"
  description = "${local.project}-app-rule"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "${local.project}-app-rule"
    sampled_requests_enabled   = false
  }
}