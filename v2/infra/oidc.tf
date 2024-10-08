resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["0123456789012345678901234567890123456789"] # dummy
}

resource "aws_iam_role" "github_actions_oidc" {
  name = "${local.project}-github-actions-oidc"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : aws_iam_openid_connect_provider.github_actions.arn
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringLike" : {
            "token.actions.githubusercontent.com:sub" : "repo:i544c-me/buicha-social:*"
          },
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_oidc_policy" {
  name = "${local.project}-github-actions-oidc-policy"
  role = aws_iam_role.github_actions_oidc.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow"
        "Action" : ["ec2:DescribeImages"]
        "Resource" : "*"
      }
    ]
  })
}
