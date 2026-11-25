# SQS 큐와 DLQ

표준 큐 또는 FIFO 큐를 SQS 관리형 암호화와 20초 롱 폴링으로 생성합니다. `max_receive_count`를 지정하면 같은 유형의 실패 메시지 보관용 DLQ가 생깁니다. DLQ에는 이 소스 큐만 연결할 수 있도록 redrive 허용 정책을 설정합니다. [AWS SQS DLQ 운영 지침](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-dead-letter-queues.html)

```hcl
module "payment_events" {
  source                     = "./modules/terraform-aws-sqs"
  name                       = "payments-prod-events"
  max_receive_count          = 5
  visibility_timeout_seconds = 120
}
```

플랫폼 저장소 루트 기준 예시입니다. 소비자의 최대 처리 시간을 기준으로 가시성 제한 시간을 결정합니다. 소스 큐는 기본 4일, DLQ는 14일간 보존합니다. FIFO를 선택하면 모듈이 `.fifo`를 붙입니다. 소비 실패 시 순서를 유지해야 하는 서비스는 DLQ가 이후 메시지 처리 순서에 미치는 영향을 확인하세요. [AWS provider 5.100 SQS 명세](https://registry.terraform.io/providers/hashicorp/aws/5.100.0/docs/resources/sqs_queue)
