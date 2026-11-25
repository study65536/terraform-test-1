# terraform-aws-ecr

태그 불변성과 푸시 시 이미지 스캔을 설정한 프라이빗 ECR 저장소를 만듭니다.

플랫폼 소스를 체크아웃한 저장소 루트에서 조합하는 예시입니다.

```hcl
module "registry" {
  source = "./modules/terraform-aws-ecr"

  name                          = "payments/dev"
  untagged_image_retention_days = 30
}
```

`repository_url`, `repository_arn`을 반환합니다. `kms_key_arn`으로 접근 정책이 준비된 고객 관리 키를 사용할 수 있습니다. [AWS ECR 보안 통제](https://docs.aws.amazon.com/securityhub/latest/userguide/ecr-controls.html)

[모든 입력](variables.tf) · [모든 출력](outputs.tf)
