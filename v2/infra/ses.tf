resource "aws_ses_domain_identity" "buicha_social" {
  domain = local.main_domain
}

resource "aws_ses_domain_dkim" "buicha_social" {
  domain = aws_ses_domain_identity.buicha_social.domain
}

resource "aws_ses_domain_mail_from" "buicha_social" {
  domain           = aws_ses_domain_identity.buicha_social.domain
  mail_from_domain = "mail.${aws_ses_domain_identity.buicha_social.domain}"
}


## no-reply

resource "aws_ses_email_identity" "no_reply_buicha_social" {
  email = "no-reply@${local.main_domain}"
}

resource "aws_ses_domain_mail_from" "no_reply_buicha_social" {
  domain           = aws_ses_email_identity.no_reply_buicha_social.email
  mail_from_domain = "mail.${aws_ses_domain_identity.buicha_social.domain}"
}


### SMTP ###

resource "aws_iam_user" "ses_smtp" {
  name = "${local.project}-ses-smtp"
}

resource "aws_iam_user_policy" "ses_smtp_user" {
  name = "${local.project}-ses-smtp"
  user = aws_iam_user.ses_smtp.name
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "ses:SendEmail",
          "ses:SendRawEmail",
        ],
        Resource : "*"
      }
    ]
  })
}

resource "aws_iam_access_key" "ses_smtp" {
  user = aws_iam_user.ses_smtp.name
}

#output "ses_smtp_access_key" {
#  value     = aws_iam_access_key.ses_smtp.id
#  sensitive = true
#}
#
#output "ses_smtp_secret" {
#  value     = aws_iam_access_key.ses_smtp.ses_smtp_password_v4
#  sensitive = true
#}
