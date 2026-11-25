# KMS 대칭 키

단일 리전에 서비스 데이터 암복호화용 고객 관리 키와 별칭을 생성하고 자동 키 교체를 활성화합니다. 기본 키 정책은 소유 계정이 IAM 정책으로 권한을 위임하도록 합니다. 다른 계정이나 AWS 서비스 주체에 접근을 열 때는 해당 사용처에 맞는 `policy_json`을 전달합니다. [AWS KMS 기본 키 정책](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html)

```hcl
module "payments_key" {
  source      = "./modules/terraform-aws-kms"
  alias_name  = "alias/payments/prod/data"
  description = "Payments production data"
}
```

플랫폼 저장소 루트 기준 예시입니다. RDS나 S3 암호화에 `module.payments_key.key_arn`을 전달합니다. 삭제 대기 기간은 기본 30일입니다. 키를 사용하는 리소스와 보존 중인 백업의 해독 수명을 고려해 키 삭제 시점을 결정합니다. [AWS provider 5.100 KMS 키 명세](https://registry.terraform.io/providers/hashicorp/aws/5.100.0/docs/resources/kms_key)
