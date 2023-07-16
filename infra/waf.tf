resource "aws_wafv2_rule_group" "app" {
  name     = "${local.project}-app-rule-group"
  scope    = "CLOUDFRONT"
  capacity = 800

  rule {
    priority = 0
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    priority = 1
    name     = "AWS-AWSManagedRulesLinuxRuleSet"
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesLinuxRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    priority = 2
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesSQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    priority = 3
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_wafv2_web_acl" "app" {
  provider    = aws.us_east_1
  name        = "${local.project}-app-rule"
  description = "${local.project}-app-rule"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "${local.project}-app-rule-group"
    priority = 1

    statement {
      rule_group_reference_statement {
        arn = aws_wafv2_rule_group.app.arn
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "${local.project}-app-rule"
    sampled_requests_enabled   = false
  }
}