resource "aws_route53_record" "this" {
  for_each = var.records

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.alias == null ? each.value.values : null

  dynamic "alias" {
    for_each = each.value.alias[*]
    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = alias.value.evaluate_target_health
    }
  }
}
