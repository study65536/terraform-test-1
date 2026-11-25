# Lambda 함수

같은 리전의 버전 관리 S3 버킷에서 ZIP의 정확한 객체 버전을 읽어 Lambda 함수 버전을 게시하고, 로그 그룹과 보존 기간을 관리합니다. 실행 역할에는 Lambda 신뢰 정책과 해당 로그 그룹 쓰기 권한이 필요합니다. ZIP 업로드와 이벤트 소스 연결은 호출자가 관리합니다. [AWS Lambda ZIP 배포](https://docs.aws.amazon.com/lambda/latest/dg/configuration-function-zip.html)

아래는 [IAM 역할](../terraform-aws-iam-role/README.md) 예시를 함께 사용하는 호출입니다. `artifact_version`에는 빌드 결과의 S3 VersionId를 전달합니다. 출력은 함수 ARN, 게시된 버전, 로그 그룹 이름입니다.

```hcl
module "worker" {
  source             = "./modules/terraform-aws-lambda-function"
  name               = "orders-dev-worker"
  execution_role_arn = module.worker_role.arn
  handler            = "handler.main"
  runtime            = "python3.12"
  package = {
    bucket  = var.artifact_bucket
    key     = "orders/worker.zip"
    version = var.artifact_version
  }
}
```
