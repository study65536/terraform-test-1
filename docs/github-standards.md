# GitHub 공식 가이드와 이 프로젝트의 적용

저장소 수를 정하는 기준은 이 조직 예제에서 선택한 **코드 소유자, 배포 권한, 변경 주기**입니다. 같은 팀이 결제 승인과 정산을 운영하므로 하나의 결제 도메인 저장소를 쓰고, 조직 정책과 공통 모듈 배포에는 각각 별도 저장소를 씁니다. 아래 표는 GitHub가 제공하는 기능, 코드에 들어간 부분, 저장소 관리자가 설정해야 하는 부분을 연결합니다.

| 주제 | 프로젝트에 적용한 내용 | GitHub 공식 자료 |
|---|---|---|
| 조직 팀과 저장소 권한 | 플랫폼·보안 팀에 거버넌스 쓰기, 플랫폼 팀에 라이브러리 쓰기, 결제 팀에 도메인 쓰기를 부여합니다. 모듈을 읽는 주체에는 라이브러리 저장소 읽기만 부여합니다. GitHub의 실제 팀과 접근 권한은 조직 관리자가 설정합니다. | [About teams](https://docs.github.com/en/organizations/organizing-members-into-teams/about-teams) |
| 경로별 리뷰 | `.github/CODEOWNERS.example`의 조직·팀 이름을 실제 쓰기 권한이 있는 팀으로 바꾸고 파일명을 `CODEOWNERS`로 변경합니다. 정책·카탈로그·워크플로 경로별로 검토자를 지정합니다. CODEOWNERS는 리뷰 담당자를 정하며, 읽기 접근 범위는 저장소 권한으로 정합니다. | [About code owners](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners) |
| 기본 브랜치 규칙 | `main-review.json` 예시는 기본 브랜치 삭제·강제 푸시 제한, PR 승인 1명, 코드 소유자 승인, 변경 후 재승인과 대화 해결을 지정합니다. 관리자는 **Settings → Rules → Rulesets → Import a ruleset**에서 가져온 뒤 실제 팀·예외·필수 상태 검사를 확인합니다. 적용 가능 범위는 저장소 공개 여부와 요금제를 따릅니다. | [About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets) · [Creating or importing rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository) |
| 재사용 가능한 CI | 라이브러리의 `.github/workflows/reusable-domain.yml`이 `workflow_call` 인터페이스를 제공합니다. 도메인 저장소는 해당 워크플로의 전체 커밋 SHA를 지정하고 변경된 서비스·환경을 검증합니다. 모듈 버전과 CI 버전은 독립적으로 승격할 수 있습니다. | [Reuse workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows) · [Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use) |
| 비공개 저장소 간 접근 | 호출받는 라이브러리 저장소의 **Settings → Actions → General → Access**에서 조직의 호출 저장소가 워크플로를 사용할 수 있도록 설정합니다. Terraform의 비공개 Git 모듈 다운로드에는 별도로 라이브러리 Contents 읽기 권한의 자격 증명이 필요합니다. | [Sharing workflows with your organization](https://docs.github.com/en/actions/how-tos/reuse-automations/share-with-your-organization) · [Automatic token authentication](https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication) |
| 운영 배포와 AWS 인증 | 제공되는 PR 검증은 AWS 리소스 변경 없이 진행합니다. 실제 apply 작업을 연결할 때 GitHub Environment의 승인자와 허용 브랜치를 정하고, AWS 역할의 OIDC 신뢰 조건에서 조직·저장소·환경과 audience를 제한합니다. 상태 버킷에서도 해당 서비스·환경 키와 잠금 파일에만 필요한 권한을 부여합니다. | [Deployment environments](https://docs.github.com/en/actions/concepts/workflows-and-actions/deployment-environments) · [OIDC in AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws) |

## 적용 순서

1. 라이브러리·거버넌스·도메인용 빈 저장소를 준비하고 쓰기 팀을 각각 지정합니다. 각 저장소에서 첫 커밋을 푸시한 뒤 코드 소유자 파일과 ruleset을 설정합니다.
2. 비공개 라이브러리의 워크플로 공유와 모듈 Git 읽기 권한을 각각 연결합니다. 테스트 PR 하나에서 도메인의 개발 환경만 변경해 어떤 검증이 실행되는지 확인합니다.
3. 첫 실행에서 확인한 검사 이름을 기본 브랜치의 필수 상태 검사에 추가합니다. 운영 apply를 연결할 경우 검증과 배포에 서로 다른 권한을 부여합니다.
4. 도메인 저장소가 많아지면 GitHub 조직의 custom properties에 `domain`, `owner-team`, `repository-type`을 지정해 검색·규칙 적용 범위에 활용할 수 있습니다. 카탈로그의 AWS 배포 대상 및 상태 키는 Terraform 배포 과정에서 사용합니다. [Managing custom properties for repositories](https://docs.github.com/en/organizations/managing-organization-settings/managing-custom-properties-for-repositories-in-your-organization)
