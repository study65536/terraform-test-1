# 독립 모듈 저장소 발행

원본 키트에서 검토할 변경을 로컬 커밋으로 확정하고 저장소 루트에서 실행합니다. 스크립트는 선택한 커밋의 Git 트리에서 `modules/`, `stacks/workload/`의 Terraform·문서·테스트 파일과 라이브러리에 필요한 CI, 잠금 파일, README만 추출합니다. 조직 정책·계정 카탈로그는 거버넌스 저장소에서 관리합니다. [Git archive](https://git-scm.com/docs/git-archive)

```bash
python3 scripts/export-library.py --ref HEAD --output ../terraform-aws-library
cd ../terraform-aws-library
git init
git add .
git diff --cached --stat
git commit -m "Publish AWS workload stack and modules"
git branch -M main
git remote add origin git@github.com:ORG/terraform-aws-library.git
git push -u origin main
git rev-parse HEAD
```

마지막 명령의 SHA가 서비스 루트와 재사용 워크플로가 참조할 **라이브러리 버전**입니다. 생성한 `SOURCE-REVISION`에는 릴리스의 원본 키트 커밋이 기록됩니다. GitHub Ruleset에서 PR, 필수 리뷰어, CI 통과를 요구하도록 저장소 정책을 설정할 수 있습니다. [GitHub Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)

후속 릴리스는 작업 트리가 깨끗한 라이브러리 체크아웃에 릴리스용 브랜치를 만든 뒤, 키트 루트에서 같은 `export-library.py` 명령을 새 `--ref`로 실행합니다. 기존 발행 기준과 변경 파일을 대조한 뒤 추가·갱신·삭제할 파일을 함께 stage합니다. `git diff --cached`로 변경을 확인하고 커밋·PR을 생성합니다. 라이브러리 저장소에서 발행 관리 대상 파일을 직접 수정한 경우 변경을 원본 키트에도 반영하는 등 두 소스의 소유권을 먼저 정리합니다. 자체 서비스 운영 문서처럼 발행 대상 밖의 추가 파일은 별도로 유지할 수 있습니다.
