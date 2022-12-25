terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 4.48"
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