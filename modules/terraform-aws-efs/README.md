# terraform-aws-efs

암호화된 EFS와 AZ별 마운트 대상, 클라이언트 보안 그룹의 NFS 규칙을 만듭니다.

플랫폼 소스를 체크아웃한 저장소 루트에서 조합하는 예시입니다.

```hcl
module "shared_files" {
  source = "./modules/terraform-aws-efs"

  name                      = "payments-dev-files"
  vpc_id                    = module.vpc.vpc_id
  subnet_ids_by_az          = module.vpc.private_subnet_ids_by_az
  client_security_group_ids = { web = module.web_sg.security_group_id }
}
```

`dns_name`, `file_system_id`를 반환합니다. 클라이언트는 EFS SG로 나가는 TCP 2049 접근과 TLS 마운트 구성이 필요합니다. [AWS EFS 네트워크 접근](https://docs.aws.amazon.com/efs/latest/ug/network-access.html)

[모든 입력](variables.tf) · [모든 출력](outputs.tf)
