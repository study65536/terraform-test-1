# RDS for PostgreSQL

하나의 VPC 안에서 프라이빗 DB 서브넷 그룹과 암호화된 PostgreSQL 인스턴스를 생성합니다. 기본값은 Multi-AZ, 7일 자동 백업, 삭제 방지입니다. RDS가 관리자 비밀번호를 Secrets Manager에 저장하고 순환하며, Terraform 출력은 시크릿 ARN을 제공합니다. [AWS RDS 암호 관리](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html)

아래 경로는 플랫폼 저장소 루트에서 호출하는 예입니다. 리전에서 지원되는 엔진 버전과 클래스, 서로 다른 AZ의 서브넷을 선택하세요. DB 보안 그룹에는 애플리케이션 보안 그룹에서 오는 TCP 5432 접근을 허용합니다.

```hcl
module "payments_db" {
  source                    = "./modules/terraform-aws-rds"
  identifier                = "payments-prod"
  database_name             = "payments"
  engine_version            = var.postgres_version
  instance_class            = var.db_instance_class
  private_subnet_ids        = values(module.vpc.private_subnet_ids_by_az)
  security_group_ids        = [var.database_security_group_id]
  final_snapshot_identifier = "payments-prod-final-001"
}
```

종료 시에는 먼저 삭제 방지 해제를 적용하고, 해당 리전에 동일한 이름의 스냅샷이 있는지 확인한 뒤 고유한 최종 스냅샷 이름으로 삭제 계획을 실행합니다. 애플리케이션은 전용 DB 사용자로 접속하도록 구성합니다. [AWS provider 5.100 RDS 명세](https://registry.terraform.io/providers/hashicorp/aws/5.100.0/docs/resources/db_instance)
