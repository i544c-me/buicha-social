terraform {
  required_version = "1.9.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.63.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.39.0"
    }
  }

  backend "s3" {
    bucket = "buichasocial-v2-production-tfstate"
    key    = "buichasocial-v2-production.tfstate"
    region = "ap-northeast-1"
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

provider "cloudflare" {
}

data "aws_caller_identity" "current" {}
locals {
  account_id = data.aws_caller_identity.current.account_id
}
