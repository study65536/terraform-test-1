# 공통 AWS 모듈

HashiCorp의 공개 Registry는 원본 저장소에 `terraform-<PROVIDER>-<NAME>` 규칙을 적용합니다. 이 카탈로그는 AWS 모듈 디렉터리에도 같은 규칙을 사용합니다. 예를 들어 VPC는 `terraform-aws-vpc`, EC2 인스턴스는 `terraform-aws-ec2-instance`입니다. 호출자가 정하는 HCL 레이블(`module "network"` 등)은 Terraform 상태의 주소에 쓰입니다. 공개 모듈 유지보수자들도 이 이름으로 VPC와 ALB 구현을 배포합니다. [HashiCorp Registry 발행 요건](https://developer.hashicorp.com/terraform/registry/modules/publish) · [표준 모듈 구조](https://developer.hashicorp.com/terraform/language/modules/develop/structure) · [공개 VPC 모듈](https://github.com/terraform-aws-modules/terraform-aws-vpc) · [공개 ALB 모듈](https://github.com/terraform-aws-modules/terraform-aws-alb)

각 디렉터리의 `main.tf`에는 실제 AWS 리소스, `variables.tf`에는 입력 계약, `outputs.tf`에는 다른 모듈과 연결할 값이 있습니다. 이 저장소를 Git으로 배포할 때 팀은 릴리스 태그 또는 커밋 SHA로 패키지 버전을 고정하고 `//modules/terraform-aws-vpc`처럼 하위 경로를 선택합니다. Git 소스의 `ref`는 저장소 전체에 적용됩니다. Registry에 각 모듈을 별도 배포하려면 개별 모듈을 해당 이름의 저장소 루트에 두고 버전 태그를 발행할 수 있습니다. [Terraform 모듈 소스와 하위 디렉터리](https://developer.hashicorp.com/terraform/language/modules/sources)

각 서비스의 환경 루트가 계정·리전과 `ServiceCode`, `Environment` 같은 공통 태그를 결정합니다. 모듈은 호출자가 전달한 AWS provider를 상속하고 생성한 리소스의 ID를 출력합니다. 같은 리소스가 여러 개면 서비스 코드에서 안정적인 논리 이름을 키로 `for_each`를 사용하세요. 이름이 유지되는 동안 목록 순서가 바뀌어도 리소스 주소가 유지됩니다.

| 모듈 | 입력 예 | 생성하는 리소스와 운영 기준 | 주요 출력 |
| --- | --- | --- | --- |
| [terraform-aws-vpc](terraform-aws-vpc/) | VPC CIDR, AZ 이름별 퍼블릭·프라이빗 CIDR | VPC, 인터넷 게이트웨이, 서브넷과 라우팅 테이블. `nat_gateway_per_az`를 켜면 각 AZ의 프라이빗 서브넷이 같은 AZ의 NAT를 사용합니다. | `vpc_id`, `private_subnet_ids_by_az`, `private_route_table_ids_by_az` |
| [terraform-aws-ec2-instance](terraform-aws-ec2-instance/) | AMI ID, 유형, 서브넷, 보안 그룹 | 사설 IP를 사용하는 인스턴스 한 대, IMDSv2, 암호화된 gp3 루트 디스크. SSH 키와 IAM 인스턴스 프로파일은 선택 사항입니다. | `instance_id`, `private_ip`, `availability_zone` |
| [terraform-aws-ebs-volume](terraform-aws-ebs-volume/) | AZ, 용량, 선택적 연결 대상 | 암호화된 gp3 데이터 디스크와 선택적 EC2 연결. 삭제 전 최종 스냅샷은 `final_snapshot`으로 지정합니다. | `volume_id`, `volume_arn` |
| [terraform-aws-s3-bucket](terraform-aws-s3-bucket/) | 파티션 내 고유 버킷 이름, 선택적 KMS 키 | 버킷 소유권 강제, 퍼블릭 접근 차단, 버전 관리, 서버 측 암호화. 비어 있지 않은 버킷을 삭제하려면 별도 데이터 수명주기 절차가 필요합니다. | `bucket_name`, `bucket_arn` |
| [terraform-aws-efs](terraform-aws-efs/) | AZ별 서브넷 ID, 클라이언트 이름별 보안 그룹 ID | 암호화된 EFS, AZ별 마운트 대상, 허용한 클라이언트 SG의 TCP 2049 접근, 기본 자동 백업. | `file_system_id`, `dns_name`, `mount_target_ids` |
| [terraform-aws-eks](terraform-aws-eks/) | 지원 중인 Kubernetes 버전, 서로 다른 AZ의 서브넷, 관리자 역할 ARN | 프라이빗 API 엔드포인트, 제어 영역 로그, 관리형 노드 그룹, 노드·클러스터 IAM 역할과 관리자 액세스 엔트리. | `cluster_name`, `cluster_endpoint`, `cluster_security_group_id` |
| [terraform-aws-ecr](terraform-aws-ecr/) | 리포지토리 이름, 선택적 KMS 키·보존 일수 | 변경 불가 이미지 태그, 푸시 시 스캔 설정, 선택적 미태깅 이미지 만료 정책. | `repository_url`, `repository_arn` |
| [terraform-aws-alb](terraform-aws-alb/) | TLS 인증서 ARN, 서브넷, SG, 대상 인스턴스 맵 | ALB, HTTPS 리스너, 대상 그룹과 상태 확인, 선택적 HTTP 리다이렉트 | dns_name, zone_id, target_group_arn |
| [terraform-aws-security-group](terraform-aws-security-group/) | 방향과 피어별 규칙 맵 | VPC 보안 그룹, 목적별 ingress·egress 규칙 | security_group_id |
| [terraform-aws-vpc-endpoints](terraform-aws-vpc-endpoints/) | 게이트웨이·인터페이스 엔드포인트 맵 | S3·DynamoDB 게이트웨이, PrivateLink 인터페이스, 라우팅과 보안 그룹 연결 | gateway_endpoint_ids, interface_endpoint_ids |
| [terraform-aws-rds](terraform-aws-rds/) | PostgreSQL 엔진 버전, 클래스, 프라이빗 서브넷, SG | RDS PostgreSQL, 서브넷 그룹, 관리형 마스터 자격 증명 | address, master_secret_arn |
| [terraform-aws-dynamodb-table](terraform-aws-dynamodb-table/) | 테이블 이름, 파티션 키, 선택적 정렬 키 | 온디맨드 DynamoDB 테이블과 복구·암호화 설정 | name, arn |
| [terraform-aws-kms](terraform-aws-kms/) | 별칭, 선택적 키 정책 | 회전되는 대칭 암호화 키와 별칭 | 키 ARN |
| [terraform-aws-iam-role](terraform-aws-iam-role/) | 신뢰 정책 JSON, 권한 정책, 선택적 권한 경계 | 다른 서비스에 전달할 IAM 역할과 정책 연결 | arn, name |
| [terraform-aws-lambda-function](terraform-aws-lambda-function/) | S3 객체 버전, 실행 역할, 런타임, 핸들러 | 버전 관리 ZIP 기반 Lambda 함수와 CloudWatch 로그 그룹 | arn, version, log_group_name |
| [terraform-aws-route53-records](terraform-aws-route53-records/) | 호스팅 영역 및 레코드 목록 | Route 53 일반 레코드 및 alias 레코드 | 레코드 FQDN |
| [terraform-aws-cloudwatch-alarms](terraform-aws-cloudwatch-alarms/) | 지표, 차원, 임곗값, 알림 대상 | CloudWatch 지표 경보 | 경보 ARN |
| [terraform-aws-sqs](terraform-aws-sqs/) | 큐 이름, 암호화 및 재시도 옵션 | SQS 큐와 선택적 DLQ | 큐 ARN 및 URL |

## 연결할 때 확인할 값

- 네트워크 팀이 계정·리전별로 할당한 비중복 CIDR을 입력하고 AZ별 키를 명시합니다. NAT가 꺼진 프라이빗 서브넷에서 SSM, ECR, 패키지 미러 등에 접근하려면 사용하는 서비스의 VPC 엔드포인트 또는 중앙 외부 통신 경로를 연결하세요. NAT를 켜면 각 AZ에서 NAT와 공인 IPv4 비용이 발생합니다. [AWS NAT 게이트웨이 동작](https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-basics.html)
- EC2의 애플리케이션 보안 그룹과 EFS의 클라이언트 보안 그룹을 연결하면 해당 인스턴스에서 NFS 접근이 가능합니다. 마운트 명령, 파일 시스템 권한, `/etc/fstab` 관리는 호스트 구성 단계에서 수행합니다. 추가 EBS 볼륨은 EC2 출력인 `availability_zone`과 `instance_id`로 같은 AZ에 연결합니다.
- EKS의 프라이빗 API는 클러스터 생성 이후 운영자의 네트워크 경로와 API 보안 그룹 접근이 필요합니다. 관리형 노드에는 이미지 및 AWS API 접근 경로가 필요합니다. 클러스터 관리자 ARN에는 해당 환경의 운영 역할을 지정합니다. 노드 그룹이 사용하는 CNI IAM 권한은 워크로드 격리 요구에 맞춰 별도 애드온 역할로 분리할 수 있습니다. [EKS VPC 및 서브넷 요구 사항](https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html)
- 환경별로 검증한 AMI ID와 EKS 버전을 입력해 dev에서 검증한 변경을 stg, prod 순서로 승격합니다. 버전 관리, 최종 스냅샷, EFS 자동 백업 옵션과 별도로 서비스별 보존 기간과 복구 절차를 정합니다.

## AWS 권고와 예제의 설계 선택

| 모듈 | 설계 근거 | 이 저장소에서 선택한 값과 운영 시 결정할 사항 |
| --- | --- | --- |
| vpc | 여러 AZ가 공용 NAT 하나에 의존하면 해당 AZ 장애가 다른 AZ의 인터넷 접근에도 영향을 줍니다. [AWS NAT 가용성 가이드](https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-basics.html) | 예제 기본값은 NAT 꺼짐입니다. AZ별 NAT를 켤 때에는 동일 AZ 안에서 라우팅합니다. 조직의 중앙 egress VPC를 쓰면 해당 라우팅 경로를 연결합니다. |
| ec2-instance | AWS Security Reference Architecture의 애플리케이션 계정은 메타데이터 접근에 IMDSv2를 사용합니다. [AWS SRA 애플리케이션 계정](https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/application.html) | `http_tokens = "required"`로 설정합니다. 서비스 팀이 검증한 AMI를 입력하고, 기본 루트 디스크 20 GiB는 AMI의 최소 크기와 서비스의 로그 사용량에 맞춥니다. |
| ebs-volume | EC2와 연결할 볼륨은 같은 AZ에 두며, 암호화한 볼륨의 스냅샷도 암호화됩니다. 스냅샷을 사용해 다른 AZ에 새 볼륨을 만들 수 있습니다. [AWS EBS 볼륨과 스냅샷](https://docs.aws.amazon.com/ebs/latest/userguide/EBSFeatures.html) | 서비스 스택은 EC2의 AZ에 gp3 데이터 볼륨을 배치하고 prod에서 삭제 전 스냅샷을 켭니다. 정기 백업 주기와 복구 시험은 서비스의 목표 복구 시점에 맞춥니다. |
| s3-bucket | AWS는 정책으로 접근을 관리하는 버킷에 ACL 비활성화와 퍼블릭 접근 차단을 권고합니다. [S3 보안 권고](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html) | 버킷 소유권 강제, 퍼블릭 접근 차단, 버전 관리를 켭니다. 암호화 기본값은 SSE-S3이며 고객 관리형 키가 필요한 모듈 호출에서 `kms_key_arn`을 지정합니다. |
| efs | AWS는 Regional 파일 시스템의 AZ당 마운트 대상을 한 개까지 지원하며, NFS 클라이언트와 마운트 대상의 보안 그룹 사이에 TCP 2049를 허용하는 예를 제공합니다. [EFS 마운트 대상](https://docs.aws.amazon.com/efs/latest/ug/accessing-fs.html) · [EFS 네트워크 접근](https://docs.aws.amazon.com/efs/latest/ug/network-access.html) | AZ를 맵 키로 받아 마운트 대상을 만들고, 입력한 클라이언트 SG에 접근을 부여합니다. 백업은 기본 활성화합니다. 클라이언트가 전송 중 암호화를 사용하려면 EFS 마운트 옵션에 TLS를 설정합니다. [EFS TLS 가이드](https://docs.aws.amazon.com/efs/latest/ug/encryption-in-transit.html) |
| eks | EKS 액세스 엔트리는 IAM 주체와 클러스터 접근을 연결합니다. 엔드포인트 공개 범위는 클러스터에 접근하는 운영 경로에 따라 정합니다. [EKS IAM 운영 가이드](https://docs.aws.amazon.com/eks/latest/best-practices/identity-and-access-management.html) | 기본값은 프라이빗 엔드포인트와 명시한 운영 관리자 역할 한 개입니다. 관리자 추가·회수, 팀별 네임스페이스 권한, 애드온별 IAM은 배포 조직의 권한 모델에 맞춥니다. |
| ecr | AWS Security Hub는 이미지 스캔, 태그 불변성, 수명 주기 정책, 고객 관리형 키를 개별 점검 항목으로 정의합니다. [ECR 보안 통제](https://docs.aws.amazon.com/securityhub/latest/userguide/ecr-controls.html) | 모듈은 태그 불변성과 푸시 시 스캔 옵션을 설정합니다. 서비스 스택이 지정하는 미태깅 이미지 만료 기준은 푸시 후 30일입니다. 고객 관리형 키 통제를 채택한 계정은 모듈 호출에 키 ARN을 전달해야 합니다. |

공개 Terraform 코드로는 AWS Integration & Automation 팀의 EKS Blueprints에서 VPC의 프라이빗 서브넷 출력을 EKS 입력으로 넘기는 예를 볼 수 있습니다. Cloud Posse도 VPC, 파일 시스템, 이미지 저장소를 독립적으로 재사용할 수 있는 모듈로 공개합니다. 이 저장소는 그 구성 방식을 참고해 서비스 스택에서 필요한 모듈을 조합합니다. [AWS EKS Blueprints 예제](https://github.com/aws-ia/terraform-aws-eks-blueprints/blob/main/patterns/stateful/main.tf) · [Cloud Posse VPC](https://github.com/cloudposse/terraform-aws-vpc) · [Cloud Posse EFS](https://github.com/cloudposse/terraform-aws-efs) · [Cloud Posse ECR](https://github.com/cloudposse/terraform-aws-ecr)
