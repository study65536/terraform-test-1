# DynamoDB 테이블

온디맨드 요금 테이블에 파티션 키와 선택적 정렬 키를 정의합니다. 시점 복구와 삭제 보호가 기본이며, TTL 속성과 고객 관리 KMS 키를 지정할 수 있습니다. 삭제를 계획하면 먼저 삭제 보호를 해제하고 적용합니다. [AWS DynamoDB 시점 복구](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Point-in-time-recovery.html)

아래는 저장소 루트 기준의 호출 예시입니다. 결과는 `module.orders.name`, `module.orders.arn`으로 사용합니다.

```hcl
module "orders" {
  source        = "./modules/terraform-aws-dynamodb-table"
  name          = "orders-dev"
  partition_key = { name = "customer_id", type = "S" }
  sort_key      = { name = "order_id", type = "S" }
  ttl_attribute = "expires_at"
}
```
