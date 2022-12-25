resource "aws_wafv2_web_acl" "app" {
  provider    = aws.us_east_1
  name        = "${local.project}-app-rule"
  description = "${local.project}-app-rule"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "block-bot"
    priority = 1

    action {
      captcha {}
    }
    statement {
      regex_match_statement {
        regex_string = "^/auth/"
        field_to_match {
          uri_path {}
        }
        text_transformation {
          priority = 1
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "${local.project}-app-rule"
      sampled_requests_enabled   = false
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "${local.project}-app-rule"
    sampled_requests_enabled   = false
  }
}