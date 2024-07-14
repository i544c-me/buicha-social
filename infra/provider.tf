terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "5.58"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.0.5"
    }
  }

  cloud {
    organization = "i544c-me"
    workspaces {
      name = "buicha-social"
    }
  }

  required_version = "1.9.2"
}

provider "aws" {
  region = "ap-northeast-1"
}

data "tls_certificate" "tfc_certificate" {
  url = "https://${var.tfc_hostname}"
}

resource "aws_iam_openid_connect_provider" "tfc_provider" {
  url             = data.tls_certificate.tfc_certificate.url
  client_id_list  = [var.tfc_aws_audience]
  thumbprint_list = [data.tls_certificate.tfc_certificate.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "tfc_role" {
  name = "tfc-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : aws_iam_openid_connect_provider.tfc_provider.arn
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "${var.tfc_hostname}:aud" : one(aws_iam_openid_connect_provider.tfc_provider.client_id_list)
          },
          "StringLike" : {
            "${var.tfc_hostname}:sub" : [
              "organization:${var.tfc_organization_name}:project:${var.tfc_project_name}:workspace:${var.tfc_workspace_name}:run_phase:*"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "tfc_role" {
  role       = aws_iam_role.tfc_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

data "aws_caller_identity" "current" {}
locals {
  account_id = data.aws_caller_identity.current.account_id
}