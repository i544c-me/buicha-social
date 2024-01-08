data "cloudflare_zone" "main" {
  name = local.main_domain
}

resource "cloudflare_record" "main" {
  zone_id = data.cloudflare_zone.main.id
  name    = "@"
  type    = "CNAME"
  value   = "buiso-v2-production-runners-1670176063.ap-northeast-1.elb.amazonaws.com"
  proxied = true
}

resource "cloudflare_page_rule" "api" {
  zone_id  = data.cloudflare_zone.main.id
  target   = "buicha.social/api/*"
  priority = 2

  actions {
    cache_level = "bypass"
  }
}

resource "cloudflare_page_rule" "old_media" {
  zone_id  = data.cloudflare_zone.main.id
  target   = "buicha.social/files/*"
  priority = 1

  actions {
    forwarding_url {
      url         = "https://media.buicha.social/files/$1"
      status_code = "301"
    }
  }
}

resource "cloudflare_record" "ses_txt" {
  zone_id = data.cloudflare_zone.main.id
  name    = "_amazonses.${local.main_domain}"
  type    = "TXT"
  value   = aws_ses_domain_identity.buicha_social.verification_token
  comment = "buicha.social SES"
}

resource "cloudflare_record" "ses_dkim" {
  for_each = toset(aws_ses_domain_dkim.buicha_social.dkim_tokens)

  zone_id = data.cloudflare_zone.main.id
  name    = "${each.value}._domainkey.${local.main_domain}"
  type    = "CNAME"
  value   = "${each.value}.dkim.amazonses.com"
  comment = "buicha.social SES DKIM"

  depends_on = [aws_ses_domain_dkim.buicha_social]
}

resource "cloudflare_record" "ses_spf" {
  zone_id = data.cloudflare_zone.main.id
  name    = aws_ses_domain_mail_from.buicha_social.mail_from_domain
  type    = "TXT"
  value   = "v=spf1 include:amazonses.com ~all"
  comment = "buicha.social SES SPF"
}

resource "cloudflare_record" "ses_mailfrom" {
  zone_id  = data.cloudflare_zone.main.id
  name     = aws_ses_domain_mail_from.buicha_social.mail_from_domain
  type     = "MX"
  priority = 10
  value    = "feedback-smtp.ap-northeast-1.amazonses.com"
  comment  = "buicha.social SES Feedback"
}


resource "cloudflare_record" "ses_dmark" {
  zone_id = data.cloudflare_zone.main.id
  name    = "_dmarc.${local.main_domain}"
  type    = "TXT"
  value   = "v=DMARC1;p=quarantine;adkim=r;aspf=r;rua=mailto:report@i544c.me;"
  comment = "buicha.social SES DMARK"
}
