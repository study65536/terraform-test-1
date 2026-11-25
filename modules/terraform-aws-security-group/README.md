# terraform-aws-security-group

VPC 보안 그룹과 맵 키로 식별한 TCP·UDP·ICMP 또는 전체 프로토콜 규칙을 만듭니다. IPv4·IPv6 CIDR, 보안 그룹, 프리픽스 목록을 피어로 사용할 수 있습니다.

플랫폼 소스를 체크아웃한 저장소 루트에서 조합하는 예시입니다.

```hcl
module "web_sg" {
  source = "./modules/terraform-aws-security-group"

  name   = "payments-dev-web"
  vpc_id = module.vpc.vpc_id
  rules = {
    ansible_ssh = {
      direction = "ingress", ip_protocol = "tcp", from_port = 22, to_port = 22
      referenced_security_group_id = var.controller_sg_id
    }
  }
}
```

기본 규칙 맵은 비어 있습니다. 워크로드가 연결을 시작하는 경우에는 목적지별 egress를 추가합니다. 두 SG가 서로를 참조한다면 그룹 ID를 먼저 생성하고 한 쪽의 규칙을 호출 스택의 독립 규칙 리소스로 선언해 순환 참조를 피할 수 있습니다. `security_group_id`가 출력됩니다. [AWS 보안 그룹 규칙](https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html)

[모든 입력](variables.tf) · [모든 출력](outputs.tf)
