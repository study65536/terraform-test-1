# 조직 공통 거버넌스

기존 AWS Organizations와 Control Tower 랜딩 존을 전제로 합니다. 서비스 300개에서도 워크로드 계정 수는 각 도메인의 배포 대상 매핑에 따라 결정됩니다. 계정 수가 늘면 OU의 소속과 계정 카탈로그를 갱신합니다. 조직 제어는 OU 단위로 상속되고, 사람의 권한은 필요한 계정과 그룹에 할당됩니다.

| Terraform 루트 | 실행 계정·리전 | 적용 단위와 기본 동작 |
| --- | --- | --- |
| `control-tower/` | 조직 관리 계정의 Control Tower 홈 리전 | 선택적 제어 ARN과 OU ARN의 조합 하나당 활성화 한 건. 초기 대상은 비어 있습니다. |
| `scp/` | 조직 정책을 관리할 관리 계정 | EBS 기본 암호화 해제를 거부하는 고객 관리 SCP 한 개. 초기에는 대상 OU가 비어 있습니다. |
| `iam/` | IAM Identity Center 위임 관리자 계정의 Identity Center 리전 | EC2 메타데이터 조회용 권한 세트 한 개. 초기에는 그룹에 할당하지 않습니다. |

## OU와 계정 온보딩

```text
Organization
├── Security                감사 및 로그 보관 계정
├── Infrastructure          네트워크, 공유 서비스, 자동화 계정
├── Policy-Staging          신규 정책을 검증할 대표 계정
└── Workloads
    ├── NonProd             서비스 dev 및 stg 계정
    └── Prod                서비스 prod 계정
```

1. 플랫폼 팀이 기존 Organizations와 Control Tower의 홈 리전, 감사·로그 보관 계정, OU와 등록 상태를 확인합니다. 랜딩 존이 없는 조직은 Control Tower 설정을 먼저 완료합니다. 기존 회원 계정은 파일럿 OU에서 기준선 적용과 등록 결과를 확인한 뒤 OU별로 단계적으로 등록합니다. [기존 OU 등록](https://docs.aws.amazon.com/controltower/latest/userguide/importing-existing.html)
2. 새 계정은 Account Factory를 사용합니다. 계정 신청을 Git에서 승인하려면 전용 AFT 관리 계정과 계정 신청 저장소를 연결한 뒤 그 저장소에서 계정 이름, 고유 이메일, 대상 OU를 담은 요청을 병합합니다. 기존 계정을 AFT로 편입할 때는 등록 상태와 Service Catalog provisioned product를 확인합니다. [AFT 계정 신청](https://docs.aws.amazon.com/controltower/latest/userguide/aft-provision-account.html) · [기존 계정 편입](https://docs.aws.amazon.com/controltower/latest/userguide/aft-update-account.html)
3. 계정 발급과 기준선 확인이 끝나면 실제 계정 ID, 담당 팀, 서비스와 환경을 `catalog/accounts.json`에 등록합니다. 예제 ID는 교체하고 서비스 Terraform 실행 역할과 상태 버킷을 준비합니다. 서비스 인프라 변경은 해당 서비스 환경 루트에서 실행합니다.
4. 기존에 콘솔 또는 별도 Terraform에서 관리하는 제어와 권한은 기존 소유권을 확인합니다. 이 저장소로 관리권을 옮길 때는 해당 리소스를 import하고 변경 없는 첫 plan을 확인합니다. Control Tower가 직접 관리하는 기준선·역할·정책의 변경은 Control Tower 수명 주기를 따릅니다.

## Control Tower 제어와 SCP의 적용 순서

`control-tower/terraform.tfvars.example`에는 EBS 볼륨의 암호화를 점검하는 탐지 제어 예시가 있습니다. 제어의 전역 ARN과 대상 OU ARN을 입력합니다. 탐지 제어를 쓰는 OU에는 AWS Config 기록을 지원하는 기준선과 해당 리전 지원이 필요합니다. [Terraform으로 제어 관리](https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/deploy-and-manage-aws-control-tower-controls-by-using-terraform.html) · [제어별 요구 사항](https://docs.aws.amazon.com/controltower/latest/controlreference/control-considerations.html)

`scp/`의 정책은 `ec2:DisableEbsEncryptionByDefault` 호출을 거부합니다. 이 설정은 계정·리전별이므로 신규 계정 기준선에서 기본 암호화를 먼저 활성화합니다. 이미 존재하는 볼륨은 탐지 결과에 따라 별도로 처리합니다. SCP는 회원 계정 권한의 상한을 정하고, 실제 접근 권한은 IAM 정책이 부여합니다. 관리 계정과 서비스 연결 역할에는 SCP가 적용되지 않습니다. [SCP의 적용 범위](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)

Organizations의 모든 기능 및 SCP 유형을 활성화하고 현재 계층의 Allow 정책과 기존 Control Tower 제어를 확인합니다. `target_ou_ids`에 파일럿 OU 하나를 지정해 의도한 API 거부와 서비스 배포 성공을 검증합니다. 이후 NonProd, Prod 순서로 대상을 추가합니다. 운영 장애로 적용을 되돌릴 때는 문제 OU를 대상에서 제거한 plan을 검토하고 적용합니다. 상위 OU에 연결된 동일한 제한도 함께 확인합니다.

## 계정별 접근 권한

`iam/`의 `EC2InventoryReader` 권한 세트는 인스턴스·상태·태그 조회 세 가지 API만 허용합니다. Identity Provider에서 동기화한 그룹의 Identity Store ID와 카탈로그의 서비스·환경 키를 입력하면 해당 계정에만 그룹 권한이 할당됩니다. 예를 들어 결제 개발팀을 `01_PAYMENTS/dev`에만 등록하면 이 할당으로 결제 dev 계정의 EC2 목록을 확인할 수 있습니다. 같은 계정에 결제 승인·정산 서비스가 함께 있으면 이 권한은 그 계정 전체에서 EC2 메타데이터를 조회할 수 있습니다. 동일 계정·그룹을 여러 서비스에서 요청해도 AWS 할당은 하나로 관리합니다. 기존 예시의 상태 주소는 카탈로그의 계정별 assignment_key로 보존합니다. AWS CLI의 `aws sso-admin list-instances`로 조직 인스턴스 ARN을 확인합니다. [위임 관리자 권한과 관리 계정 예외](https://docs.aws.amazon.com/singlesignon/latest/userguide/delegated-admin-how-to-register.html)

서비스 배포 자동화는 계정·환경별 실행 역할을 사용하고, 애플리케이션 권한은 EC2 인스턴스 프로파일이나 EKS 워크로드 역할에 배정합니다. 그룹에 부여한 인벤토리 조회 권한, Terraform 배포 권한, 애플리케이션의 데이터 접근 권한을 각각의 실행 주체에 맞게 검토할 수 있습니다.

## 다중 계정 정책의 변경 이력

키트에서는 실제 입력값이 담긴 `*.tfvars.json`을 Git에서 제외합니다. 별도로 내보낸 비공개 거버넌스 저장소에서는 `platform/{control-tower,scp,iam}/governance.auto.tfvars.json`에 OU·그룹 할당을 기록해 PR로 검토할 수 있습니다. Terraform이 이 파일을 자동으로 읽습니다. 아래는 `platform/scp/governance.auto.tfvars.json`에 파일럿 OU를 지정하는 예입니다.

```json
{
  "target_ou_ids": ["ou-abcd-12345678"]
}
```

같은 방식으로 Control Tower는 `controls`, IAM은 `inventory_readers`를 관리합니다. 로컬 `terraform.tfvars`에는 실행 계정과 리전을 지정하고, 같은 대상 목록은 한 파일에서 관리합니다. 공개 예제에는 가상 식별자를 사용하며 인증 정보는 CI 환경의 임시 자격 증명으로 전달합니다.

## 플랫폼 루트 실행

각 루트는 고유한 S3 상태 키와 잠금 파일을 사용합니다. 실행 계정에는 해당 플랫폼 상태에 접근할 수 있는 버킷과 역할이 필요합니다. 아래는 저장소 루트에서 관리 계정의 SCP 계획을 보는 예시입니다. 같은 방식으로 `control-tower`와 `iam`의 계정, 리전 및 변수를 준비합니다.

```bash
export AWS_PROFILE=organization-policy-admin
aws sts get-caller-identity
cd platform/scp
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars에서 실행 계정과 리전을 설정하고, 필요한 경우 파일럿 OU ID를 추가합니다.
terraform init -backend-config="bucket=${PLATFORM_STATE_BUCKET}" \
  -backend-config="region=${PLATFORM_STATE_REGION}"
terraform validate
terraform plan -out=scp.tfplan
```

버킷 이름과 버킷이 있는 리전은 각각 `PLATFORM_STATE_BUCKET`, `PLATFORM_STATE_REGION`에 지정합니다. 계획의 OU·계정·할당을 검토하고 이 계획을 배포할 때는 `terraform apply scp.tfplan`을 사용합니다. 권한 정책을 여러 OU에 확대할 때는 같은 상태에서 적용한 이전 OU 대상을 유지합니다.
