# 서비스 워크로드 스택

각 서비스 환경의 `main.tf`는 이 스택의 Git 커밋을 참조합니다. 배포 계정은 호출자가 결정합니다. 서비스 카탈로그에서 배정된 VPC CIDR와 AZ를 바탕으로 퍼블릭·프라이빗 서브넷을 만들며, 인스턴스, 데이터 디스크, 파일 스토리지, 컨테이너 클러스터는 환경별 사양으로 추가합니다. 서비스 버킷과 ECR은 기본 활성화입니다. 모듈 연결은 [main.tf](main.tf)와 [connectivity.tf](connectivity.tf)에 있습니다.

## 같은 계정의 VPC·EKS 공유

대상 계정의 서비스 한 개가 해당 환경의 네트워크 소유자로 지정됩니다. 소유 루트가 VPC·서브넷·라우팅과 선택적 NAT, 게이트웨이 엔드포인트, Flow Logs를 먼저 배포합니다. 소비자 루트에는 카탈로그가 `workload.shared_network_owner_code`를 전달합니다. 예를 들어 결제 팀 정산 서비스가 `payments-dev` VPC를 쓸 때 이 값은 `payments`입니다. 스택은 대상 계정·리전에서 소유자의 `ServiceCode`, `Environment`, `Name` 태그로 VPC를 찾고 CIDR을 확인합니다. 각 AZ의 프라이빗 서브넷은 그 VPC의 ID·AZ·이름 태그로 조회합니다. 이 경로에는 EC2 조회 권한이 필요합니다. 적용 순서와 태그는 [공유 인프라 조회](shared-infrastructure.tf)에 있습니다. [AWS provider의 VPC 조회](https://registry.terraform.io/providers/hashicorp/aws/5.100.0/docs/data-sources/vpc) · [HashiCorp 모듈 조합](https://developer.hashicorp.com/terraform/language/modules/develop/composition)

기존 클러스터를 사용하는 서비스는 `workload.shared_eks_cluster_name`에 소유 팀이 배포한 이름을 지정합니다. 스택은 `eks:DescribeCluster`로 조회한 VPC가 해당 서비스의 VPC와 일치하는지 확인하고 클러스터 이름을 출력합니다. EFS를 선택하면 해당 클러스터 보안 그룹을 NFS 클라이언트로 연결합니다. 클러스터 팀이 EKS 업그레이드와 접근 엔트리를 관리하고, Kubernetes 네임스페이스와 앱 배포 권한은 도메인별로 설정합니다. [AWS provider의 EKS 조회](https://registry.terraform.io/providers/hashicorp/aws/5.100.0/docs/data-sources/eks_cluster)

기존 단독 VPC 소유 루트는 업그레이드 뒤에도 소유자로 유지하세요. 같은 스택 안에서 네트워크의 Terraform 주소는 `module.vpc`에서 `module.vpc[0]`으로 이동하며 [moved 블록](moved.tf)이 기존 상태를 연결합니다. 이미 운영 중인 네트워크 소유자를 다른 상태로 바꿀 때는 별도의 소유권 이전 작업이 필요합니다. 양쪽 apply를 일시 중지하고 상태 백업 후 소유 리소스 주소와 AWS ID를 대조해 기존 상태에서 분리하고 새 소유 상태로 편입합니다. 양쪽 plan에서 기존 VPC·서브넷·EKS에 예기치 않은 생성·삭제·교체가 없는지 확인한 뒤 배포를 재개합니다. 소유자 코드를 먼저 바꾸면 기존 소유 상태가 삭제를 계획할 수 있습니다. [Terraform 구성 간 리소스 이전](https://developer.hashicorp.com/terraform/language/state/refactor)

## Nginx 웹 서버로 들어오는 경로

아래는 서비스 저장소 `services/01_PAYMENTS/dev/workload.json` 예시입니다. AMI와 인증서 ARN은 해당 계정·리전의 실제 값으로 교체하고, `client_cidrs`에는 내부 로드 밸런서에 접근할 사설 클라이언트 대역을 지정합니다. 인스턴스가 패키지 저장소에 접속할 수 있는 NAT/프록시 경로와 egress, Ansible 제어 서버의 SSH 접근은 환경에 맞춰 구성합니다.

```json
{
  "instances": {
    "web-01": {
      "ami_id": "ami-0123456789abcdef0",
      "availability_zone": "ap-northeast-2a",
      "role": "web"
    }
  },
  "gateway_endpoints": ["s3"],
  "alb": {
    "certificate_arn": "arn:aws:acm:ap-northeast-2:111111111101:certificate/00000000-0000-0000-0000-000000000001",
    "client_cidrs": ["10.80.0.0/16"],
    "target_instances": ["web-01"],
    "target_port": 80,
    "health_path": "/healthz"
  }
}
```

내부 ALB는 두 AZ 이상의 프라이빗 서브넷에서 HTTPS 443을 수신합니다. ALB 보안 그룹에서 대상 포트로 가는 경로를 열고 등록된 EC2로 요청을 전달합니다. 웹 서버에서 `/healthz`가 HTTP 200을 반환하면 타깃이 정상화됩니다. S3 게이트웨이 엔드포인트는 프라이빗 라우팅 테이블에 연결됩니다. EC2의 HTTPS egress 및 S3 데이터 권한은 애플리케이션 요구 사항에 따라 별도로 부여합니다. [ALB 대상 그룹](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html) · [게이트웨이 엔드포인트](https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html)

## 서비스 전용 모듈 추가

서비스 팀은 환경 루트에 `database.tf` 등을 추가해 [모듈 카탈로그](../../modules/README.md)의 모듈을 직접 호출할 수 있습니다. 다음 예시는 RDS가 같은 VPC의 프라이빗 서브넷을 쓰도록 연결합니다. `ORG/terraform-aws-library`과 `COMMIT_SHA`는 게시된 저장소와 검증한 40자리 커밋으로 교체하고, DB 입력과 DB용 보안 그룹을 같은 루트에서 정의합니다.

```hcl
module "orders_db" {
  source                    = "git::https://github.com/ORG/terraform-aws-library.git//modules/terraform-aws-rds?ref=COMMIT_SHA"
  identifier                = "orders-prod"
  private_subnet_ids        = values(module.workload.private_subnet_ids_by_az)
  security_group_ids        = [var.database_security_group_id]
  engine_version            = var.postgres_version
  instance_class            = var.database_class
  database_name             = "orders"
  final_snapshot_identifier = var.final_snapshot_identifier
}
```

이 호출은 해당 환경의 상태에서 관리됩니다. 데이터베이스를 별도 팀이 운영하거나 복구·배포 주기가 따로 있다면 별도 루트와 상태를 둘 수 있습니다. 기존 스택의 모듈 호출 이름 변경은 [moved.tf](moved.tf)에 기록했습니다. [Terraform 모듈 리팩터링](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)
