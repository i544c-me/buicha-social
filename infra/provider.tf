terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "= 4.48"
      configuration_aliases = [aws.us_east_1]
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "= 3.30.0"
    }
  }

  backend "s3" {
    bucket = "tf-example-private"
    key    = "buichasocial/terraform.tfstate"
    region = "us-east-1"
  }

  required_version = "= 1.3.6"
}

provider "aws" {
  region = "ap-northeast-1"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}