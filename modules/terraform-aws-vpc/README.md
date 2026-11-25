# terraform-aws-vpc

AZ별 퍼블릭·프라이빗 서브넷, 인터넷 게이트웨이, 라우팅 테이블을 구성합니다. AZ별 NAT와 S3 VPC Flow Logs는 입력으로 활성화합니다.

플랫폼 소스를 체크아웃한 저장소 루트에서 조합하는 예시입니다.

```hcl
module "vpc" {
  source = "./modules/terraform-aws-vpc"

  name     = "payments-dev"
  vpc_cidr = "10.16.0.0/20"
  subnets_by_az = {
    ap-northeast-2a = { public_cidr = "10.16.0.0/24", private_cidr = "10.16.8.0/24" }
    ap-northeast-2c = { public_cidr = "10.16.1.0/24", private_cidr = "10.16.9.0/24" }
  }
}
```

`private_subnet_ids_by_az`로 EC2·RDS·EKS를 연결하고, `private_route_table_ids_by_az`로 게이트웨이 엔드포인트를 연결합니다. NAT 기본값은 꺼짐입니다. 공개 인터넷 통신이 필요한 경우 AZ별 NAT 또는 중앙 경로를 준비합니다. `flow_log = { destination_arn = var.log_bucket_arn }` 지정 시 S3 로그 전달 권한이 필요합니다. [AWS VPC 다중 AZ 예제](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-example-private-subnets-nat.html) · [S3 Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-s3.html)

[모든 입력](variables.tf) · [모든 출력](outputs.tf)
