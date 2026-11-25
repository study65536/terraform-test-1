# terraform-aws-alb

HTTPS 리스너가 EC2 대상 그룹으로 요청을 전달합니다. 기본 구성은 내부 ALB, 삭제 방지 활성화, 443 리스너와 /healthz 검사입니다.

플랫폼 소스를 체크아웃한 저장소 루트에서 조합하는 예시입니다.

```hcl
module "frontend" {
  source = "./modules/terraform-aws-alb"

  name               = "payments-dev"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = values(module.vpc.private_subnet_ids_by_az)
  security_group_ids = [module.alb_sg.security_group_id]
  certificate_arn    = var.acm_certificate_arn
  targets            = { web_01 = module.web.instance_id }
}
```

`dns_name`, `zone_id`를 Route 53 alias에, `target_group_arn`을 Auto Scaling 그룹에 전달할 수 있습니다. 같은 리전의 인증서와 서로 다른 AZ의 충분한 여유 IP가 있는 서브넷이 필요합니다. ALB egress와 서버 ingress 양쪽에 대상 포트를 허용합니다. `internal = false`이면 인터넷 게이트웨이로 라우팅되는 퍼블릭 서브넷을 전달합니다. [AWS ALB 서브넷 및 보안 그룹](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html) · [HTTPS 리스너](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html)

[모든 입력](variables.tf) · [모든 출력](outputs.tf)
