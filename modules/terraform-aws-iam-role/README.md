# IAM 역할

호출자가 맡을 수 있는 주체를 신뢰 정책으로 지정하고, 역할이 실행할 수 있는 동작을 인라인 또는 관리형 정책으로 부여합니다. 조직에서 권한 경계가 필요하면 `permissions_boundary_arn`을 지정합니다. [AWS 서비스 역할과 권한](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-service.html)

저장소 루트에서 호출하는 예시입니다. Lambda 함수 모듈에 `module.worker_role.arn`을 전달할 수 있습니다.

```hcl
module "worker_role" {
  source = "./modules/terraform-aws-iam-role"
  name   = "orders-dev-worker"
  trust_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  inline_policies = {
    logs = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:ap-northeast-2:111111111101:log-group:/aws/lambda/orders-dev-worker:*"
      }]
    })
  }
}
```
