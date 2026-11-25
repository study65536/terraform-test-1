# terraform-aws-vpc-endpoints

S3·DynamoDB 게이트웨이 엔드포인트에 라우팅 테이블을 연결하고 PrivateLink 인터페이스 엔드포인트에는 AZ별 서브넷과 SG를 지정합니다.

플랫폼 소스를 체크아웃한 저장소 루트에서 조합하는 예시입니다.

```hcl
module "private_access" {
  source = "./modules/terraform-aws-vpc-endpoints"

  vpc_id = module.vpc.vpc_id
  gateway_endpoints = {
    s3 = {
      service_name    = "com.amazonaws.ap-northeast-2.s3"
      route_table_ids = values(module.vpc.private_route_table_ids_by_az)
    }
  }
  interface_endpoints = {
    ecr_api = {
      service_name       = "com.amazonaws.ap-northeast-2.ecr.api"
      subnet_ids         = values(module.vpc.private_subnet_ids_by_az)
      security_group_ids = [var.endpoint_sg_id]
    }
  }
}
```

`gateway_endpoint_ids`, `interface_endpoint_ids`를 반환합니다. 서비스·리전별 지원 엔드포인트 이름을 확인하세요. 인터페이스 SG에는 클라이언트에서 오는 서비스 포트(보통 TCP 443)를 허용합니다. ECR PrivateLink를 통해 이미지를 받으려면 ECR API 외에 ECR Docker 엔드포인트와 S3 경로가 필요합니다. [게이트웨이 엔드포인트](https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html) · [인터페이스 엔드포인트 생성](https://docs.aws.amazon.com/vpc/latest/privatelink/create-interface-endpoint.html) · [Amazon ECR VPC 엔드포인트](https://docs.aws.amazon.com/AmazonECR/latest/userguide/vpc-endpoints.html)

[모든 입력](variables.tf) · [모든 출력](outputs.tf)
