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
  zone_id  = data.cloudflare_zone.main.id
  target   = "${local.main_domain}/api/*"
  priority = 3

  actions {
    cache_level = "bypass"
  }
}

resource "cloudflare_page_rule" "old_media" {
  zone_id  = data.cloudflare_zone.main.id
  target   = "${local.main_domain}/files/*"
  priority = 4

  actions {
    forwarding_url {
      url         = "https://media.${local.main_domain}/files/$1"
      status_code = "301"
    }
  }
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
  comment = "${local.main_domain} ACM for ALB"
}
