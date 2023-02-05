resource "aws_ses_domain_identity" "buicha_social" {
  provider = aws.us_east_1
  domain   = local.main_domain
}

resource "aws_ses_domain_dkim" "buicha_social" {
  provider = aws.us_east_1
  domain   = aws_ses_domain_identity.buicha_social.domain
}

resource "aws_ses_domain_mail_from" "buicha_social" {
  provider         = aws.us_east_1
  domain           = aws_ses_domain_identity.buicha_social.domain
  mail_from_domain = "mail.${aws_ses_domain_identity.buicha_social.domain}"
}