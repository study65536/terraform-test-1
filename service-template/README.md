# 도메인 저장소 생성과 이전

하나의 운영 팀이 여러 서비스를 관리하고, 각 서비스는 `services/NN_SERVICE/{dev,stg,prod}/`에 독립된 실행 루트를 갖습니다. 계정과 네트워크를 공유하는 결제·정산 서비스가 예시입니다. 서비스 수와 환경 수는 카탈로그에서 명시하고 실제 AWS 계정은 여러 서비스가 참조할 수 있습니다.

## 신규 서비스 등록과 도메인 내보내기

기존 대상 이름은 카탈로그의 배포 대상 목록에서 확인합니다. 기존 결제 도메인에 새 서비스 하나를 추가하는 예시입니다.

```bash
python3 scripts/new-service.py register 04_REFUNDS --domain payments \
  --targets payments-dev payments-stg payments-prod
python3 scripts/catalog.py
git diff -- catalog/accounts.json
```

공통 모듈과 재사용 워크플로가 배포된 GitHub 저장소 URL을 지정합니다. 리비전에는 검증된 **모듈 배포 저장소**의 40자리 소문자 커밋 SHA를 사용합니다. 같은 저장소의 해당 리비전에 `.github/workflows/reusable-domain.yml`이 있으면 기본값으로 공동 사용합니다. 별도 CI 저장소를 운영하면 `--workflow-repo ORG/SHARED-CI --workflow-ref <40자리 SHA>`를 함께 지정합니다.

```bash
library=https://github.com/ORG/terraform-aws-library.git
release_sha=$(git ls-remote "$library" refs/heads/main | cut -f1)
python3 scripts/new-service.py export payments --module-repo "$library" \
  --ref "$release_sha" --output ../payments-infra
cd ../payments-infra
python3 scripts/check-roots.py
```

`--output`에는 플랫폼 저장소 외부의 경로를 사용합니다. 처음 내보낸 결과를 팀 GitHub 저장소에 커밋합니다. 이후 등록한 서비스를 같은 도메인 저장소에 내보내면 기존 루트에 있는 팀별 설정과 이미 승격된 모듈 SHA가 보존됩니다. 중앙 할당 변경은 플랫폼에서 `python3 scripts/new-service.py account-map 01_PAYMENTS dev`로 생성한 할당과 기존 루트의 `account.json`을 비교하고 도메인 PR에서 반영합니다.

```text
payments-infra/
├── domain.json
├── services/
│   ├── 01_PAYMENTS/{dev,stg,prod}/    환경마다 main.tf, account.json, workload.json, lock file
│   └── 03_SETTLEMENT/{dev,stg,prod}/  결제와 같은 대상 계정을 사용할 수 있음
├── scripts/                          선택·초기화·검증
└── .github/workflows/terraform.yml   버전 고정한 공통 워크플로 호출
```

공유 VPC는 카탈로그에 기록한 네트워크 소유 서비스의 루트에서 한 번 배포합니다. 같은 대상을 쓰는 서비스들은 소유자의 VPC와 서브넷을 조회합니다. 같은 EKS를 이용하는 서비스는 운영 중인 클러스터 이름을 지정하고 클러스터의 실제 관리 권한을 소유자에게 유지합니다. 다른 도메인의 공유 환경을 참조하면 소유자가 먼저 배포하고, 의존하는 도메인에서도 변경 영향을 확인합니다.

## GitHub Actions 검증 방식

도메인 저장소의 작은 호출 워크플로가 `uses: ORG/REPO/.github/workflows/reusable-domain.yml@SHA`로 공통 잡을 호출합니다. `contents: read` 권한과 비공개 모듈용 읽기 토큰을 명시합니다. 같은 커밋에서 Terraform 자체의 공통 모듈 변경과 CI 변경을 따로 승격할 수 있습니다. [GitHub 재사용 워크플로 공식 문서](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows) · [GitHub Actions의 보안 강화](https://docs.github.com/en/actions/reference/security/secure-use)

선택기는 PR 기준 커밋에서 병합할 코드까지 변경된 파일 목록을 Git에서 읽습니다. 기존 브랜치 push는 이전 커밋을 사용하고 새 브랜치와 수동 실행은 전체 루트를 검증합니다. 서비스 설정 변경은 해당 환경, 같은 대상의 공유 네트워크·EKS 변경은 도메인 내 관련 환경, 공통 코드 변경은 전체 도메인을 선택합니다. 상태 경로 삭제 시 처리한 마이그레이션을 확인할 수 있게 `retired-roots.json`에 기록합니다. 전체 변경이더라도 최대 32개 배치, 동시 실행 4개로 나눕니다. GitHub Actions의 단일 매트릭스 잡 제한은 256개입니다. [GitHub Actions 제한](https://docs.github.com/en/actions/reference/limits) · [워크플로 문법](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)

## 기존 실행 루트에서 이전

1. 기존 서비스의 각 환경에 대해 AWS 계정·리전, S3 버킷과 상태 키, 사용 중인 provider와 모듈 SHA, 리소스 주소를 확인합니다. 서비스별 저장소라면 해당 배포 파이프라인의 apply를 일시 중지합니다.
2. 기존 서비스 코드와 AWS 계정·네트워크 소유권을 중앙 카탈로그에 매핑합니다. 도메인 저장소를 내보낸 후 기존 `dev/workload.json` 같은 입력과 팀 고유의 Terraform 구성을 새 경로 `services/01_PAYMENTS/dev/` 등에 옮깁니다. 배포 이력이 있는 서로 다른 VPC를 한 대상으로 합치는 변경은 별도 네트워크 마이그레이션으로 계획합니다.
3. 같은 버킷과 `services/01_PAYMENTS/dev/terraform.tfstate` 키로 초기화합니다. `module.workload` 주소를 유지하고 `terraform -chdir=services/01_PAYMENTS/dev state list`와 첫 plan에서 예상 밖 생성·교체·삭제 여부를 확인합니다. 이전 세대 스택의 모듈 이름 변경은 배포 라이브러리의 `stacks/workload/moved.tf`에 기록되어 있습니다. 같은 상태와 리소스 주소를 쓰는 디렉터리 이동 자체에는 상태 복사가 필요하지 않습니다. [HashiCorp S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3) · [모듈 리팩터링](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)
4. dev, stg, prod 순서로 도메인 저장소에 배포 소유권을 넘기고 기존 파이프라인의 쓰기 권한을 제거합니다. [팀 저장소에 포함되는 운영 안내](team-readme.md.tmpl)
