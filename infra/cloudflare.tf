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

resource "cloudflare_record" "ses_dkim" {
  for_each = toset(aws_ses_domain_dkim.buicha_social.dkim_tokens)

  zone_id = data.cloudflare_zone.main.id
  name    = "${each.value}._domainkey.${local.main_domain}"
  type    = "CNAME"
  value   = "${each.value}.dkim.amazonses.com"
  comment = "buicha.social SES DKIM"

  depends_on = [aws_ses_domain_dkim.buicha_social]
}
