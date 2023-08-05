data "aws_s3_bucket" "media" {
  bucket = "media.buicha.social"
}

data "aws_iam_policy_document" "main" {
  version = "2012-10-17"

  // Cloudflare
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:GetObject"]
    resources = [
      data.aws_s3_bucket.media.arn,
      "${data.aws_s3_bucket.media.arn}/*"
    ]
    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks
    }
  }

  // Admin
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:GetObject"]
    resources = [
      data.aws_s3_bucket.media.arn,
      "${data.aws_s3_bucket.media.arn}/*"
    ]
    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = [for ip in var.admin_ips : "${ip}/32"]
    }
  }
}

resource "aws_s3_bucket_policy" "main" {
  bucket = data.aws_s3_bucket.media.id
  policy = data.aws_iam_policy_document.main.json
}

resource "aws_s3_bucket_acl" "main" {
  bucket = data.aws_s3_bucket.media.id
  acl    = "private"
}

resource "aws_iam_user" "s3_rw" {
  name = "${local.project}-s3-rw"
}

data "aws_iam_policy" "s3_rw" {
  arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_user_policy_attachment" "s3_rw" {
  user       = aws_iam_user.s3_rw.name
  policy_arn = data.aws_iam_policy.s3_rw.arn
}

resource "aws_s3_bucket_website_configuration" "main" {
  bucket = data.aws_s3_bucket.media.id
  index_document {
    suffix = "index.html"
  }
}