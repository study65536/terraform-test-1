# Route 53 레코드

기존 호스팅 영역에서 일반 DNS 레코드와 AWS 리소스 별칭을 단순 라우팅 정책으로 관리합니다. 항목 키는 Terraform 주소로 쓰므로 이름 변경은 상태 이동과 함께 계획합니다. 같은 DNS 이름과 타입의 값을 여러 개 운영할 때는 한 항목의 `values`로 관리합니다. [AWS Route 53 별칭](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-choosing-alias-non-alias.html)

```hcl
module "payments_dns" {
  source         = "./modules/terraform-aws-route53-records"
  hosted_zone_id = var.application_zone_id

  records = {
    api = {
      name = "api.example.com"
      type = "A"
      alias = {
        name                   = var.load_balancer_dns_name
        zone_id                = var.load_balancer_canonical_zone_id
        evaluate_target_health = true
      }
    }
    internal = {
      name   = "worker.example.com"
      type   = "A"
      ttl    = 60
      values = [var.worker_private_ip]
    }
  }
}
```

플랫폼 저장소 루트 기준 예시입니다. `hosted_zone_id`는 레코드를 만드는 영역이고, 별칭 내부 `zone_id`는 ALB 등 대상 리소스의 정규 호스팅 영역 ID입니다. 기존 레코드의 소유권을 인수하는 경우 먼저 해당 `for_each` 주소로 import합니다. [AWS provider 5.100 Route 53 명세](https://registry.terraform.io/providers/hashicorp/aws/5.100.0/docs/resources/route53_record)
