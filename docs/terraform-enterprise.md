# 300개 서비스에서 Terraform 실행 플랫폼 선택하기

대형 조직이 Terraform Enterprise(TFE)를 직접 운영한 사례가 있습니다. AXA는 2023년 발표에서 AWS 사설 네트워크에 설치한 TFE를 그룹 내 약 35개 조직이 공유하며 신규 애플리케이션과 클라우드 이전에 사용했다고 설명했습니다. Deutsche Bank는 GitHub에 코드를 두고 Terraform Enterprise와 Sentinel로 Google Cloud 랜딩 존의 셀프서비스와 정책 검사를 운영한 사례를 공개했습니다. 두 사례는 고객별 선택을 보여주며 전체 대기업의 제품별 사용 비율을 제공하지 않습니다. [AXA 담당자 발표](https://www.hashicorp.com/en/resources/building-a-migration-factory-with-terraform-enterprise-at-axa-group) · [Deutsche Bank 사례](https://www.hashicorp.com/en/case-studies/deutsche-bank)

| 운영 모델 | 적합한 조건 | 누가 무엇을 운영하는가 |
|---|---|---|
| 현재 키트의 Terraform CLI + S3 | 기존 AWS 실행 역할, 상태 버킷, 사내 배포 절차를 쓸 때 | GitHub Actions가 코드 검증을 수행합니다. 팀이 지정한 실행 환경에서 plan·apply하고 플랫폼 팀이 상태 보존·접근, 실행 권한과 이력을 구성합니다. |
| HCP Terraform | 조직이 SaaS에 상태·실행 기록을 보관할 수 있고 중앙 실행과 정책 관리가 필요할 때 | HashiCorp가 서비스를 운영합니다. 사설망 접근이 필요한 작업은 해당 네트워크에 에이전트를 배치할 수 있습니다. |
| Terraform Enterprise | 상태·로그와 실행을 고객 통제 환경에 두어야 하고 직접 운영할 팀이 있을 때 | 고객이 라이선스를 갖춘 인스턴스를 운영합니다. 플랫폼 팀이 업그레이드, 가용성, 백업·복구 및 용량을 맡습니다. |

사설 VPC에 접근할 필요와 상태를 사내에 보관할 의무는 각각 확인합니다. HCP Terraform 에이전트는 사설망에서 SaaS로 아웃바운드 연결을 열어 작업을 수행합니다. 조직 정책이 허용하는 상태 보관 위치, 필요한 동시 실행 수와 복구 목표를 기준으로 모델과 비용을 비교할 수 있습니다. [Terraform 제품 비교](https://developer.hashicorp.com/terraform/intro/terraform-editions) · [HCP Terraform 에이전트](https://developer.hashicorp.com/terraform/cloud-docs/agents) · [TFE 운영 문서](https://developer.hashicorp.com/terraform/enterprise)

## GitHub 도메인 저장소와 workspace 연결

GitHub에는 도메인별 코드·커밋·PR·리뷰 기록을 둡니다. TFE를 선택하면 **workspace 하나가 하나의 환경 루트를 실행하고 자체 Terraform 상태를 관리**하도록 매핑할 수 있습니다. 결제 팀의 TFE project를 `payments`로 둔 경우를 예로 들면 다음과 같습니다. [TFE projects와 팀 접근](https://developer.hashicorp.com/terraform/enterprise/projects) · [workspace 작업 디렉터리](https://developer.hashicorp.com/terraform/enterprise/workspaces/settings)

| GitHub 저장소 | working directory | TFE workspace 예시 | AWS 배포 대상 |
|---|---|---|---|
| `payments-infra` | `services/01_PAYMENTS/dev` | `payments-dev-apne2` | 결제 dev 계정, VPC 소유 |
| `payments-infra` | `services/03_SETTLEMENT/dev` | `settlement-dev-apne2` | 같은 계정·VPC, 별도 상태 |
| `payments-infra` | `services/01_PAYMENTS/prod` | `payments-prod-apne2` | 결제 prod 계정, 운영 권한 |

이 방식에서 서비스 300개에 환경이 세 개씩이면 워크로드 workspace는 900개입니다. 플랫폼 정책 등 독립 상태는 별도로 셉니다. 도메인 30개가 팀의 권한 경계라면 30개 GitHub 도메인 저장소로 관리할 수 있습니다. 동일 계정에서도 서비스별 workspace에 허용할 AWS IAM 역할을 별도로 지정합니다. 계정·리전·환경 매핑은 기존 카탈로그를 사용하고, 규모가 커지면 공식 `hashicorp/tfe` provider로 project와 workspace 설정을 코드화할 수 있습니다. [TFE workspace 리소스](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/workspace) · [TFE의 AWS 임시 자격 증명](https://developer.hashicorp.com/terraform/enterprise/dynamic-provider-credentials/aws-configuration)

## 결제 dev에서 먼저 검증할 내용

1. `payments-infra`를 VCS에 연결하고 결제 dev 디렉터리, 워크스페이스 팀 권한, 라이브러리 읽기 자격 증명과 대상 AWS 역할을 지정합니다. GitHub.com과 사설 TFE를 연결하는 경우 웹훅의 인바운드 경로도 확인합니다. 공유 VPC 변경은 소유자 apply 뒤 정산 workspace에서 후속 plan을 실행하도록 연결할 수 있습니다. [VCS 연결 요구 사항](https://developer.hashicorp.com/terraform/enterprise/vcs) · [변경 경로 필터](https://developer.hashicorp.com/terraform/enterprise/workspaces/settings/vcs) · [workspace 간 run trigger](https://developer.hashicorp.com/terraform/enterprise/workspaces/settings/run-triggers)
2. 기존 S3 상태가 있다면 해당 루트의 실행을 멈추고 원본 계정·버킷·키와 상태 백업을 확인합니다. 기존 백엔드로 초기화된 작업 디렉터리에서 S3 블록을 TFE 호스트·조직·workspace를 가리키는 `cloud` 설정으로 교체하고, 공식 이전 절차에 따라 `terraform init`의 대상과 상태 복사를 확인합니다. 이 키트에서 전환하려면 S3 키를 검사하는 `scripts/check-roots.py`의 검증 로직과 S3 전용 `scripts/init-workload.py`, 신규 환경 생성 템플릿도 선택한 백엔드에 맞게 조정해야 합니다. [S3 상태 이전 예제](https://developer.hashicorp.com/terraform/tutorials/cloud/migrate-remote-s3-backend-hcp-terraform) · [CLI 연결과 이전 설정](https://developer.hashicorp.com/terraform/cli/cloud/settings)
3. 상태의 리소스 주소와 첫 plan을 대조해 예상 밖 추가·삭제·교체가 없는지 확인합니다. 작은 변경 PR에서 speculative plan, 정책 검사, 승인, apply, 감사 기록까지 검증한 후 환경별로 전환합니다. 운영 apply 권한은 TFE 한 경로에 부여합니다. AWS Organizations의 SCP는 AWS API 권한을 제한하고, TFE 정책은 Terraform 실행의 계획 단계에서 배포 조건을 검사합니다. [TFE의 PR·실행 흐름](https://developer.hashicorp.com/terraform/enterprise/workspaces/run/ui) · [TFE 정책 검사](https://developer.hashicorp.com/terraform/enterprise/policy-enforcement)
