# 계정별 Terraform 상태 버킷

각 실행 계정・리전에 버킷 하나를 먼저 준비합니다. 플랫폼 루트에도 같은 원칙을 적용합니다. `bucket.yaml`은 버킷을 만드는 작업의 상태를 CloudFormation에서 관리하므로 S3 백엔드를 사용하기 전 실행할 수 있습니다. 대상 계정에 로그인한 상태에서 저장소 루트에서 실행합니다.

```bash
export AWS_PROFILE=payments-dev
export AWS_REGION=ap-northeast-2
aws sts get-caller-identity
aws cloudformation deploy --stack-name terraform-state \
  --template-file platform/state/bucket.yaml --region "$AWS_REGION"
```

버킷 이름은 `tfstate-<account-id>-<region>`입니다. 기존 조직 버킷을 사용한다면 관리자에게 이름과 접두사 권한을 확인하고 해당 버킷을 `terraform init`에 전달합니다. 버전 관리, SSE-S3 암호화, 퍼블릭 액세스 차단, TLS 강제가 적용됩니다. 신규 계정이 많으면 동일 템플릿을 계정 기준선의 StackSets 또는 AFT 사용자 지정 단계로 배포할 수 있습니다. [AWS S3 버킷의 CloudFormation 속성](https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-s3-bucket.html) · [AWS CloudFormation StackSets](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/what-is-cfnstacksets.html)

각 루트에는 고유한 S3 객체 키를 할당합니다. 실행 역할에 해당 버킷의 필요한 접두사에 대한 `s3:ListBucket`, state 객체의 `s3:GetObject`와 `s3:PutObject`, 같은 경로의 `.tflock`에 대한 Get/Put/DeleteObject 권한을 부여합니다. 서비스 실행 역할이 조직 정책 상태를 읽을 필요는 없습니다. 상태 복구 시에는 해당 루트의 실행을 멈추고 버전 이력을 비교한 뒤 복원합니다. [Terraform S3 백엔드](https://developer.hashicorp.com/terraform/language/backend/s3)
