data "cloudflare_zone" "main" {
  name = "buicha.social"
}

resource "cloudflare_record" "main" {
  zone_id = data.cloudflare_zone.main.id
  name    = "@"
  type    = "CNAME"
  value   = "d2a6jztqapq0xw.cloudfront.net"
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