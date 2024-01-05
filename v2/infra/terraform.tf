terraform {
  required_version = "1.6.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.31.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.20.0"
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
