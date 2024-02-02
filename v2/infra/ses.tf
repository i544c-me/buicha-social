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
