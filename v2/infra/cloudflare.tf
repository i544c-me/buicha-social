data "cloudflare_zone" "main" {
  name = local.cloudflare_zone
}

resource "cloudflare_record" "main" {
  zone_id = data.cloudflare_zone.main.id
  name    = local.main_domain
  type    = "CNAME"
  value   = aws_lb.app.dns_name
  proxied = true
}

resource "cloudflare_page_rule" "api" {
  status   = "disabled"
  zone_id  = data.cloudflare_zone.main.id
  target   = "${local.main_domain}/api/*"
  priority = 2

  actions {
    cache_level = "bypass"
  }
}

resource "cloudflare_page_rule" "old_media" {
  status   = "disabled"
  zone_id  = data.cloudflare_zone.main.id
  target   = "${local.main_domain}/files/*"
  priority = 1

  actions {
    forwarding_url {
      url         = "https://media.${local.main_domain}/files/$1"
      status_code = "301"
    }
  }
}


### SES ###

resource "cloudflare_record" "ses_dkim" {
  for_each = toset(aws_ses_domain_dkim.buicha_social.dkim_tokens)

  zone_id = data.cloudflare_zone.main.id
  name    = "${each.value}._domainkey.${local.main_domain}"
  type    = "CNAME"
  value   = "${each.value}.dkim.amazonses.com"
  comment = "v2 buicha.social SES DKIM"

  depends_on = [aws_ses_domain_dkim.buicha_social]
}

resource "cloudflare_record" "ses_spf" {
  zone_id = data.cloudflare_zone.main.id
  name    = "mail"
  type    = "TXT"
  value   = "v=spf1 include:amazonses.com -all"
  comment = "v2 buicha.social SES SPF"
}

resource "cloudflare_record" "ses_mailfrom" {
  zone_id  = data.cloudflare_zone.main.id
  name     = "mail"
  type     = "MX"
  priority = 10
  value    = "feedback-smtp.ap-northeast-1.amazonses.com"
  comment  = "v2 buicha.social SES Feedback"
}

resource "cloudflare_record" "ses_dmark" {
  zone_id = data.cloudflare_zone.main.id
  name    = "_dmarc"
  type    = "TXT"
  value   = "v=DMARC1;p=reject;rua=mailto:42feccfa6c8b4b90a3beaea05b8bb132@dmarc-reports.cloudflare.net;"
  comment = "v2 buicha.social SES DMARK"
}


### ACM for ALB ###

resource "cloudflare_record" "domain_cert_alb" {
  for_each = {
    for r in aws_acm_certificate.alb.domain_validation_options : r.domain_name => {
      name  = r.resource_record_name
      type  = r.resource_record_type
      value = r.resource_record_value
    }
  }

  zone_id = data.cloudflare_zone.main.id
  name    = each.value.name
  type    = each.value.type
  value   = each.value.value
  comment = "${local.main_domain} v2 ACM for ALB"
}


### Origin CA Cert ###

resource "cloudflare_authenticated_origin_pulls" "root" {
  zone_id = data.cloudflare_zone.main.id
  enabled = true
}

# TODO: たぶんこの証明書だけじゃ足りないし、共通の鍵は使わず自分で作った方が良い
# https://developers.cloudflare.com/ssl/origin-configuration/authenticated-origin-pull/set-up/zone-level/
data "http" "cloudflare_authenticated_origin_pull_ca" {
  url = "https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem"
}

resource "aws_s3_bucket" "cert" {
  bucket = "${local.project}-cert"
}

resource "aws_s3_object" "cert" {
  bucket  = aws_s3_bucket.cert.id
  key     = "cert.pem"
  content = data.http.cloudflare_authenticated_origin_pull_ca.response_body
}
