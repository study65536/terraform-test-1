# 설계 결정과 참고 자료

| 결정 | 근거와 적용 |
|---|---|
| 조직 관리, 보안, 네트워크, 애플리케이션 책임 분리 | AWS SRA는 기능별 전용 계정과 OU의 책임을 구분합니다. 이 키트의 [거버넌스](../platform/README.md)는 선택적 Control Tower 제어·SCP·Identity Center 권한에 독립 상태를 사용합니다. [AWS SRA 조직 구조](https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/account-structure.html) |
| 운영과 비운영 격리, 도메인 안에서 계정 공유 | AWS는 production과 non-production의 경계, 같은 운영 요구를 가진 워크로드를 묶는 선택지를 설명합니다. 이 프로젝트는 각 서비스·환경을 카탈로그의 배포 대상으로 매핑하고 같은 도메인의 서비스가 같은 환경 계정과 VPC를 사용할 수 있게 했습니다. [AWS Workload OUs](https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/advanced-ous.html) |
| 공통 모듈을 독립적으로 발행 | HashiCorp의 공개 Registry 저장소 명명 규칙을 `terraform-aws-<기능>` 디렉터리에도 채택했습니다. 실제 배포 경로는 Git 소스·전체 커밋 SHA이며, 계정 카탈로그는 배포 패키지에서 제외합니다. [모듈 카탈로그](../modules/README.md) · [Registry 발행 규칙](https://developer.hashicorp.com/terraform/registry/modules/publish) · [AWS 모듈 소스 지침](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/structure.html) |
| 도메인 저장소 안에서 상태 독립 | Terraform은 루트별 상태와 입력을 분리하고 공통 모듈을 재사용할 수 있습니다. 예시는 `services/01_PAYMENTS/dev`와 `services/03_SETTLEMENT/dev`를 독립적으로 plan합니다. 같은 AWS 계정을 쓰더라도 각 서비스가 관리하는 리소스의 소유자는 하나입니다. [Terraform Style Guide](https://developer.hashicorp.com/terraform/language/style#multiple-environments) · [Module Composition](https://developer.hashicorp.com/terraform/language/modules/develop/composition) |
| 기존 인프라를 이전 | 저장소만 옮길 때 기존 AWS 계정과 백엔드 버킷·키를 확인합니다. 리소스 주소를 바꾸면 `moved` 또는 상태 이전이 필요합니다. 버전 관리와 암호화를 적용한 S3 상태 버킷은 [부트스트랩 문서](../platform/state/README.md)에 설명합니다. [Terraform refactoring](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring) · [S3 백엔드](https://developer.hashicorp.com/terraform/language/backend/s3) |
| 도메인 CI와 리뷰 규칙 | 공유 워크플로를 버전 고정하고 도메인 PR에서 변경 루트를 선택합니다. GitHub 조직·팀 설정 시 필요한 공식 링크와 저장소에 적용한 범위는 [GitHub 운영 기준](github-standards.md)에 정리했습니다. |

## 기업과 업계의 공개 사례

- **Gruntwork**는 계정 발급·접근 제어와 팀에 위임한 인프라 저장소를 구분합니다. 이 프로젝트에 반영한 부분은 중앙 거버넌스와 도메인 팀의 쓰기 권한 분리입니다. [Repository Topology](https://docs.gruntwork.io/2.0/docs/accountfactory/architecture/repository-topology/)
- **Eventbrite**의 발표는 도메인 팀의 자율적 운영과 중앙에서 표준화한 Terraform 기반 AWS 계정 운영을 설명합니다. 결제·정산을 한 도메인에 둔 것은 이 저장소의 예시입니다. [Eventbrite Terraform Landing Zones](https://www.hashicorp.com/en/resources/terraform-landing-zones-for-self-service-multi-aws-at-eventbrite)
- **REI**는 계정별 구성이 공통 모듈을 참조하고 모듈 소스를 독립 저장소에서 관리한 경험을 공개했습니다. 여기서는 서로 연동되는 모듈과 스택을 한 라이브러리 리비전으로 배포합니다. [REI Engineering](https://engineering.rei.com/cloud-engineering/infrastructure-as-code.html)
- **Volkswagen Financial Services**의 SCP 중앙 관리와 **Moeve**의 기존 계정 Control Tower 등록 사례는 조직 정책 도입 순서의 참고 자료입니다. [Volkswagen Financial Services](https://aws.amazon.com/solutions/case-studies/volkswagen-financial-services-case-study/) · [Moeve](https://aws.amazon.com/solutions/case-studies/moeve-case-study/)

## 프로젝트 규칙

서비스 번호 `NN_NAME`, 서비스별 dev/stg/prod, 예시의 서울 리전·/20 대역, 도메인 저장소 하나당 같은 운영 책임을 지는 팀이라는 가정은 이 프로젝트의 규칙입니다. 예를 들어 30개 도메인이 각 10개 서비스를 맡으면 서비스 300개에 도메인 저장소 30개가 대응합니다. 도메인마다 환경별 계정 하나를 공유한다는 가정에서는 워크로드 루트 900개가 AWS 계정 90개를 사용합니다. 실제 계정 수는 카탈로그의 배포 대상이 결정합니다.
