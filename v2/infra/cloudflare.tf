data "cloudflare_zone" "main" {
  filter = {
    name = local.cloudflare_zone
  }
}

# Cloudflare provider v5: cloudflare_record は cloudflare_dns_record に改名された
moved {
  from = cloudflare_record.main
  to   = cloudflare_dns_record.main
}

moved {
  from = cloudflare_record.ses_dkim
  to   = cloudflare_dns_record.ses_dkim
}

moved {
  from = cloudflare_record.ses_spf
  to   = cloudflare_dns_record.ses_spf
}

moved {
  from = cloudflare_record.ses_mailfrom
  to   = cloudflare_dns_record.ses_mailfrom
}

moved {
  from = cloudflare_record.ses_dmark
  to   = cloudflare_dns_record.ses_dmark
}

moved {
  from = cloudflare_record.domain_cert_alb
  to   = cloudflare_dns_record.domain_cert_alb
}

resource "cloudflare_dns_record" "main" {
  zone_id = data.cloudflare_zone.main.id
  name    = local.main_domain
  type    = "CNAME"
  content = aws_lb.app_v4.dns_name
  proxied = true
  ttl     = 1
}

resource "cloudflare_page_rule" "api" {
  status   = "disabled"
  zone_id  = data.cloudflare_zone.main.id
  target   = "${local.main_domain}/api/*"
  priority = 2

  actions = {
    cache_level = "bypass"
  }
}

resource "cloudflare_page_rule" "old_media" {
  status   = "disabled"
  zone_id  = data.cloudflare_zone.main.id
  target   = "${local.main_domain}/files/*"
  priority = 1

  actions = {
    forwarding_url = {
      url         = "https://media.${local.main_domain}/files/$1"
      status_code = 301
    }
  }
}


### SES ###

resource "cloudflare_dns_record" "ses_dkim" {
  for_each = toset(aws_ses_domain_dkim.buicha_social.dkim_tokens)

  zone_id = data.cloudflare_zone.main.id
  name    = "${each.value}._domainkey.${local.main_domain}"
  type    = "CNAME"
  content = "${each.value}.dkim.amazonses.com"
  comment = "v2 buicha.social SES DKIM"
  ttl     = 1

  depends_on = [aws_ses_domain_dkim.buicha_social]
}

resource "cloudflare_dns_record" "ses_spf" {
  zone_id = data.cloudflare_zone.main.id
  name    = "mail.${local.main_domain}"
  type    = "TXT"
  content = "v=spf1 include:amazonses.com include:_spf.google.com -all"
  comment = "v2 buicha.social SES SPF"
  ttl     = 1
}

resource "cloudflare_dns_record" "ses_mailfrom" {
  zone_id  = data.cloudflare_zone.main.id
  name     = "mail.${local.main_domain}"
  type     = "MX"
  priority = 10
  content  = "feedback-smtp.ap-northeast-1.amazonses.com"
  comment  = "v2 buicha.social SES Feedback"
  ttl      = 1
}

resource "cloudflare_dns_record" "ses_dmark" {
  zone_id = data.cloudflare_zone.main.id
  name    = "_dmarc.${local.main_domain}"
  type    = "TXT"
  content = "v=DMARC1;p=reject;rua=mailto:42feccfa6c8b4b90a3beaea05b8bb132@dmarc-reports.cloudflare.net;"
  comment = "v2 buicha.social SES DMARK"
  ttl     = 1
}


### ACM for ALB ###

resource "cloudflare_dns_record" "domain_cert_alb" {
  for_each = {
    for r in aws_acm_certificate.alb.domain_validation_options : r.domain_name => {
      name  = r.resource_record_name
      type  = r.resource_record_type
      value = r.resource_record_value
    }
  }

  zone_id = data.cloudflare_zone.main.id
  # v5 では name が API の返す FQDN と一致する必要があるため、ACM の末尾のドットを除く
  name    = trimsuffix(each.value.name, ".")
  type    = each.value.type
  content = trimsuffix(each.value.value, ".")
  comment = "${local.main_domain} v2 ACM for ALB"
  ttl     = 1
}
