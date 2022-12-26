resource "aws_s3_bucket" "main" {
  bucket        = "buichasocial"
  force_destroy = true
}

#data "aws_iam_policy_document" "main" {
#  statement {
#    sid    = ""
#    effect = "Allow"
#
#    actions = [
#      "s3:GetObject"
#    ]
#
#    resources = [
#      "arn:aws:s3:::buichasocial-files",
#      "arn:aws:s3:::buichasocial-files/*"
#    ]
#  }
#}

resource "aws_s3_bucket_acl" "main" {
  bucket = aws_s3_bucket.main.id
  acl    = "private"
  #policy = data.aws_iam_policy_document.main.json
}

resource "aws_s3_bucket_website_configuration" "main" {
  bucket = aws_s3_bucket.main.bucket

  index_document {
    suffix = "index.html"
  }
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