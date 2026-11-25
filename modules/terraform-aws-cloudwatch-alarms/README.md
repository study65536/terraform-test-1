# CloudWatch 지표 경보

서비스 환경의 지표와 임계값을 경보 이름별로 지정합니다. SNS 토픽 ARN을 경보 전환 및 복구 작업에 연결하면 구독한 운영 채널에서 알림을 받을 수 있습니다. [AWS CloudWatch 경보](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html)

```hcl
module "database_alarms" {
  source = "./modules/terraform-aws-cloudwatch-alarms"
  alarms = {
    "payments-prod-db-cpu" = {
      namespace           = "AWS/RDS"
      metric_name         = "CPUUtilization"
      dimensions          = { DBInstanceIdentifier = module.payments_db.identifier }
      period_seconds      = 300
      evaluation_periods  = 3
      datapoints_to_alarm = 2
      threshold           = 80
      alarm_action_arns   = [var.ops_topic_arn]
      ok_action_arns      = [var.ops_topic_arn]
    }
  }
}
```

플랫폼 저장소 루트 기준 예시입니다. 이 경보는 세 번의 5분 평가 구간 중 두 번 이상 평균 CPU가 80%를 넘으면 경보를 발생시킵니다. 실제 워크로드의 평시 부하와 지표 발행 주기에 맞춰 조정합니다. 결과 `alarm_arns`는 경보 이름으로 조회합니다. [AWS provider 5.100 CloudWatch 명세](https://registry.terraform.io/providers/hashicorp/aws/5.100.0/docs/resources/cloudwatch_metric_alarm)
