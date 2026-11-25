# terraform-aws-s3-bucket

서비스 버킷에 버전 관리, 퍼블릭 액세스 차단, 버킷 소유자 강제 및 서버 측 암호화를 설정합니다.

플랫폼 소스를 체크아웃한 저장소 루트에서 조합하는 예시입니다.

```hcl
module "artifacts" {
  source = "./modules/terraform-aws-s3-bucket"

  name        = var.artifact_bucket_name
  kms_key_arn = var.storage_key_arn
}
```

`bucket_name`과 `bucket_arn`을 반환합니다. 버킷 이름은 AWS 파티션 내에서 고유해야 합니다. 고객 관리 KMS 키를 생략하면 SSE-S3를 사용합니다. [Amazon S3 보안 모범 사례](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)

[모든 입력](variables.tf) · [모든 출력](outputs.tf)
