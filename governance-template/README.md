# Cloud governance

이 저장소는 조직 정책과 배포 대상의 원장입니다. 플랫폼·보안 팀이 Control Tower·SCP·Identity Center를 관리하고, 서비스의 운영 도메인과 배포 대상 계정·네트워크 할당을 카탈로그에서 승인합니다. 도메인 팀은 자신의 카탈로그 사본과 배포 루트가 들어 있는 별도 저장소를 사용합니다.

| 작업 | 실행 방법 |
|---|---|
| 조직 정책·IAM 권한 검토 | [플랫폼 도입과 운영](platform/README.md) |
| 상태 버킷 준비 | [계정별 S3 백엔드](platform/state/README.md) |
| 계정·서비스·공유 대상 확인 | [배포 카탈로그](catalog/accounts.json), `python3 scripts/catalog.py` |
| 도메인 저장소 생성·기존 서비스 추가 | `python3 scripts/new-service.py --help`, [도메인 온보딩](service-template/README.md) |
| GitHub 접근·리뷰 규칙 적용 | [GitHub 공식 가이드와 적용 절차](docs/github-standards.md), [ruleset 가져오기 파일](governance-template/main-review.json) |
| 실행 플랫폼과 서버 운영 | [Terraform Enterprise 적용 판단](docs/terraform-enterprise.md), [Ansible 인벤토리와 SSH 점검](docs/ansible-inventory.md) |

`--module-repo`와 `--ref`에는 게시된 라이브러리 저장소와 **라이브러리의** 커밋을 전달합니다. `STARTER-REVISION`은 이 거버넌스 저장소를 처음 내보낸 키트의 리비전입니다. 최초 발행 후 실제 카탈로그와 정책 변경은 이 저장소에 PR로 반영합니다. [Terraform 모듈 소스](https://developer.hashicorp.com/terraform/language/modules/sources)

예시 계정 ID, OU, 리전과 네트워크 할당을 실제 값으로 바꾸고, 첫 plan에서 기존 리소스 소유권을 확인하세요. IAM Identity Center의 그룹 할당은 계정 단위입니다. 같은 계정의 여러 서비스에 애플리케이션별 권한 분리가 필요하면 별도 워크로드 역할과 리소스별 접근 정책을 사용합니다.
