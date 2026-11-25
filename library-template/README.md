# AWS 공통 Terraform 모듈 라이브러리

플랫폼 팀이 서비스에 배포하는 공통 모듈과 조합 스택입니다. [18개 모듈](../modules/README.md)에서 기능과 입출력을 살펴보고, [서비스 워크로드 스택](../stacks/workload/README.md)에서 VPC 소유 서비스와 공유 소비자의 구성을 확인하세요.

GitHub 저장소에 커밋을 게시한 뒤 `git rev-parse HEAD`로 확인한 40자리 **이 저장소의 커밋**을 도메인 팀에 전달합니다. 예를 들어 도메인 저장소에서 `git::https://github.com/ORG/terraform-aws-library.git//stacks/workload?ref=<라이브러리 커밋>`을 참조합니다. 루트의 `SOURCE-REVISION`은 패키지를 내보낸 원본 키트 커밋을 나타냅니다. [Terraform Git 소스와 하위 디렉터리](https://developer.hashicorp.com/terraform/language/modules/sources)

라이브러리 PR은 AWS 자격 증명 없이 포맷, 모듈 초기화, 검증과 모의 워크로드 계획을 수행합니다. 도메인 CI는 [.github/workflows/reusable-domain.yml](../.github/workflows/reusable-domain.yml)을 커밋 SHA로 참조합니다. 비공개 저장소에서 워크플로를 재사용할 때는 GitHub Actions의 접근 설정에서 호출 도메인 저장소를 허용하고, Terraform 모듈 다운로드에는 이 라이브러리에 대한 읽기 권한을 부여합니다. [GitHub 재사용 워크플로](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows) · [조직 안의 비공개 워크플로 공유](https://docs.github.com/en/actions/how-tos/reuse-automations/share-with-your-organization)

## GitHub 리뷰 규칙 설정

발행된 `.github/CODEOWNERS.example`의 모듈·스택·워크플로 담당자를 이 저장소에 쓰기 권한이 있는 실제 팀으로 교체하고 `.github/CODEOWNERS`로 저장합니다. 관리자는 **Settings → Rules → Rulesets → Import a ruleset**에서 발행된 `.github/rulesets/main-review.json`을 가져오고 적용 대상과 승인 규칙을 확인합니다. CI가 한 번 실행된 뒤 라이브러리 검증 작업을 필수 상태 검사로 지정할 수 있습니다. [GitHub 코드 소유자 설정](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners) · [GitHub Ruleset 가져오기](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository)
