data "cloudflare_zone" "main" {
  name = local.cloudflare_zone
}

resource "cloudflare_record" "main" {
  zone_id = data.cloudflare_zone.main.id
  name    = local.main_domain
  type    = "CNAME"
  content = aws_lb.app_v4.dns_name
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
  content = "${each.value}.dkim.amazonses.com"
  comment = "v2 buicha.social SES DKIM"

  depends_on = [aws_ses_domain_dkim.buicha_social]
}

resource "cloudflare_record" "ses_spf" {
  zone_id = data.cloudflare_zone.main.id
  name    = "mail"
  type    = "TXT"
  content = "v=spf1 include:amazonses.com include:_spf.google.com -all"
  comment = "v2 buicha.social SES SPF"
}

resource "cloudflare_record" "ses_mailfrom" {
  zone_id  = data.cloudflare_zone.main.id
  name     = "mail"
  type     = "MX"
  priority = 10
  content  = "feedback-smtp.ap-northeast-1.amazonses.com"
  comment  = "v2 buicha.social SES Feedback"
}

resource "cloudflare_record" "ses_dmark" {
  zone_id = data.cloudflare_zone.main.id
  name    = "_dmarc"
  type    = "TXT"
  content = "v=DMARC1;p=reject;rua=mailto:42feccfa6c8b4b90a3beaea05b8bb132@dmarc-reports.cloudflare.net;"
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
  content = each.value.value
  comment = "${local.main_domain} v2 ACM for ALB"
}
