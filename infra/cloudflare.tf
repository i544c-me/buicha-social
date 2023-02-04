data "cloudflare_zone" "main" {
  name = local.main_domain
}

resource "cloudflare_record" "main" {
  zone_id = data.cloudflare_zone.main.id
  name    = "@"
  type    = "CNAME"
  value   = aws_cloudfront_distribution.app.domain_name
}

resource "cloudflare_record" "domain_cert" {
  for_each = {
    for r in aws_acm_certificate.main.domain_validation_options : r.domain_name => {
      name  = r.resource_record_name
      type  = r.resource_record_type
      value = r.resource_record_value
    }
  }

  zone_id = data.cloudflare_zone.main.id
  name    = each.value.name
  type    = each.value.type
  value   = each.value.value
}

resource "cloudflare_record" "ses_txt" {
  zone_id = data.cloudflare_zone.main.id
  name    = "_amazonses.${local.main_domain}"
  type    = "TXT"
  value   = aws_ses_domain_identity.buicha_social.verification_token
}

resource "cloudflare_record" "ses_dkim" {
  for_each = toset(aws_ses_domain_dkim.buicha_social.dkim_tokens)

  zone_id = data.cloudflare_zone.main.id
  name    = "${each.value}._domainkey.${local.main_domain}"
  type    = "CNAME"
  value   = "${each.value}.dkim.amazonses.com"

  depends_on = [aws_ses_domain_dkim.buicha_social]
}

resource "cloudflare_record" "ses_spf" {
  zone_id = data.cloudflare_zone.main.id
  name    = aws_ses_domain_mail_from.buicha_social.mail_from_domain
  type    = "TXT"
  value   = "v=spf1 include:amazonses.com ~all"
}

resource "cloudflare_record" "ses_dmark" {
  zone_id = data.cloudflare_zone.main.id
  name    = "_dmarc.${local.main_domain}"
  type    = "TXT"
  value   = "v=DMARC1;p=quarantine;pct=25;rua=mailto:report@buicha.social"
}