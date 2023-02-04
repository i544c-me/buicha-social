resource "aws_ses_domain_identity" "buicha_social" {
  domain = local.main_domain
}

resource "aws_ses_domain_dkim" "buicha_social" {
  domain = aws_ses_domain_identity.buicha_social.domain
}

resource "aws_ses_domain_mail_from" "buicha_social" {
  domain           = aws_ses_domain_identity.buicha_social.domain
  mail_from_domain = "bounce.${aws_ses_domain_identity.buicha_social.domain}"
}