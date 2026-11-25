# 300개 서비스를 위한 AWS Terraform 저장소 구성

AWS 다중 계정 환경에서 조직 정책·공통 Terraform 모듈·서비스별 인프라를 독립된 Git 저장소로 관리하는 예제입니다. 결제와 정산이 한 AWS 계정을 공유하면서 dev·stg·prod 설정, 상태, 모듈 버전을 서비스별로 관리하는 방법을 담았습니다. 카탈로그와 문서의 계정 ID, 네트워크 대역, 팀 이름은 설명용 예시입니다.

| 발행할 저장소 | 소유자 | 실제 내용 |
|---|---|---|
| `cloud-governance` | 플랫폼·보안 팀 | [Control Tower, SCP, Identity Center](platform/README.md), 계정·도메인·배포 대상 카탈로그, 도메인 온보딩 도구 |
| `terraform-aws-library` | 플랫폼 팀 | [AWS 공통 모듈 18개](modules/README.md), [워크로드 스택](stacks/workload/README.md), 공통 GitHub Actions 검증 워크플로 |
| `payments-infra` | 결제 팀 | `01_PAYMENTS`와 `03_SETTLEMENT`의 dev·stg·prod. 결제 도메인에 해당하는 계정 할당만 포함 |
| `orders-infra` | 주문 팀 | `02_ORDERS`의 dev·stg·prod. 결제 팀과 독립적으로 버전 승격·배포 |

예를 들어 서비스 300개가 도메인 30개에 속하고 도메인마다 dev·stg·prod 계정 하나씩을 공유한다면, 워크로드는 **도메인 저장소 30개, 환경 루트 900개, AWS 계정 90개**가 됩니다. 여기에 거버넌스와 라이브러리 저장소가 각각 하나씩 있습니다. 실제 계정·저장소 수는 팀과 권한 경계에 맞춰 정합니다. [GitHub 공식 가이드와 코드 적용표](docs/github-standards.md) · [AWS·HashiCorp 지침 및 기업 사례](docs/design-references.md)

**이미 AWS 계정이 300개라면** 각 계정을 카탈로그의 `accounts`에 한 번 등록하고, 도메인·서비스별 `targets`에서 계정 ID를 참조합니다. 한 팀이 함께 운영하고 같은 쓰기 권한을 부여할 수 있는 서비스는 같은 저장소에 둡니다. 정산이 별도 팀으로 이관되거나 결제 운영 설정을 읽을 수 있는 인원이 달라지면 정산 저장소를 분리할 시점입니다. 디렉터리별 CODEOWNERS는 리뷰 담당자를 정하고 저장소 권한은 코드 열람 범위를 정합니다. [GitHub 팀과 리뷰 권한](docs/github-standards.md)

## 결제 승인과 정산을 따라가기

```text
cloud-governance/catalog/accounts.json
  payments 도메인 ─┬─ 01_PAYMENTS/dev   ─┬─ payments-dev 배포 대상
                  └─ 03_SETTLEMENT/dev ─┘    111111111101, ap-northeast-2

payments-infra/
  services/01_PAYMENTS/dev/       결제 dev 상태, VPC 소유
  services/01_PAYMENTS/stg/
  services/01_PAYMENTS/prod/
  services/03_SETTLEMENT/dev/     정산 dev 상태, 결제 dev의 VPC 사용
  services/03_SETTLEMENT/stg/
  services/03_SETTLEMENT/prod/
  .github/workflows/terraform.yml 라이브러리의 공통 CI를 SHA로 호출
```

[계정 카탈로그](catalog/accounts.json)는 `domains`(운영 책임), `accounts`(AWS 계정), `targets`(리전·환경·네트워크 소유자), `services`(서비스별 대상 매핑)로 구성합니다. 처음 배포할 때는 네트워크 소유자인 결제 환경을 먼저 적용합니다. 같은 환경의 정산은 결제 소유 VPC와 프라이빗 서브넷을 조회해 사용합니다. 공유 EKS가 있으면 같은 VPC의 클러스터를 이름으로 참조할 수 있습니다. 기존 서비스의 소유권을 넘기는 절차는 [도메인 이전 안내](service-template/README.md)를 참고하세요.

결제 dev의 ECR 설정만 바꾸면 CI는 `services/01_PAYMENTS/dev`만 선택합니다. 결제 dev가 소유한 공유 네트워크 설정이나 스택 버전을 바꾸면 같은 도메인에서 이 대상에 의존하는 정산 dev도 검증합니다. 다른 저장소의 도메인까지 같은 네트워크를 사용한다면 해당 팀의 워크플로도 수동 실행해 확인합니다. 운영 배포에는 서비스·환경별 S3 키와 실행 역할을 사용합니다. [변경 감지 구현](service-template/select-roots.py) · [도메인 공통 검증](.github/workflows/reusable-domain.yml)

## 이 키트를 GitHub에 게시하기

이 README는 GitHub 저장소 첫 화면에 표시됩니다. 저장소 **About** 설명 예시로는 “AWS 다중 계정 환경을 위한 Terraform 예제 · 조직 거버넌스, 공통 모듈 18개, 도메인별 dev·stg·prod 운영”을 사용할 수 있습니다.

처음 게시할 때는 `git-project/`에서 `git rev-parse --show-toplevel`로 저장소 루트를 확인합니다. `git add --dry-run .`으로 파일 목록을 보고, 스테이징한 뒤 `git diff --cached`로 실제 내용을 검토합니다. 이 키트의 [.gitignore](.gitignore)는 Terraform 상태·계획, 운영 입력값, SSH 키, 클라우드 자격 증명 파일을 제외합니다. `catalog/accounts.json`, `workload.json`, `*.tfvars.example`와 문서는 게시되므로, 여기에 입력한 실제 값은 직접 확인해야 합니다. [GitHub의 파일 제외 규칙](https://docs.github.com/en/get-started/git-basics/ignoring-files) · [Terraform 상태와 민감 정보](https://developer.hashicorp.com/terraform/language/manage-sensitive-data)

## 운영용 저장소로 분리해 발행하기

**1. 키트의 현재 소스를 로컬 Git 커밋으로 기록하고 라이브러리와 거버넌스를 추출합니다.** 키트의 Git 이력은 내보낸 디렉터리에 포함되지 않습니다. 아래 명령은 `git-project/`에서 시작하며 출력 경로는 형제 디렉터리입니다.

```bash
git add .
git diff --cached --stat
git commit -m "Build domain infrastructure starter kit"
python3 scripts/export-library.py --ref HEAD --output ../terraform-aws-library
python3 scripts/export-governance.py --ref HEAD --output ../cloud-governance
```

**2. GitHub에 두 개의 빈 저장소를 준비한 뒤 각각 커밋·푸시합니다.** `YOUR_ORG`를 본인 조직으로 교체합니다. 실제 계정·OU·네트워크 정보를 담을 거버넌스 저장소는 해당 담당 팀만 읽고 쓸 수 있게 설정합니다.

```bash
org=YOUR_ORG
for repo in terraform-aws-library cloud-governance; do
  git -C "../$repo" init
  git -C "../$repo" add .
  git -C "../$repo" commit -m "Initialize $repo"
  git -C "../$repo" branch -M main
  git -C "../$repo" remote add origin "git@github.com:$org/$repo.git"
  git -C "../$repo" push -u origin main
done
```

**3. 게시한 라이브러리의 커밋으로 결제 저장소를 생성합니다.** 키트의 SHA는 `SOURCE-REVISION`에 기록되는 출처이며 도메인의 모듈과 CI는 **별도 라이브러리 저장소의 SHA**를 참조합니다. 실제 환경은 카탈로그의 예시 값을 교체한 후 발행합니다.

```bash
library_sha=$(git -C ../terraform-aws-library rev-parse HEAD)
python3 ../cloud-governance/scripts/new-service.py export payments \
  --module-repo "https://github.com/$org/terraform-aws-library.git" \
  --ref "$library_sha" --output ../payments-infra
python3 ../payments-infra/scripts/check-roots.py
```

`payments-infra`도 자체 Git 이력과 원격 저장소로 발행합니다. 주문 팀은 `export orders`와 `--output ../orders-infra`를 사용합니다. 이미 발행한 라이브러리는 키트에서 다시 내보내거나 별도 저장소에서 리뷰·발행하는 방식 중 한 경로를 릴리스 소유자로 정합니다. 거버넌스는 최초 추출 이후 자체 저장소에서 정책과 카탈로그 PR을 처리합니다. [후속 라이브러리 릴리스 절차](library-template/PUBLISH.md)

## 운영 중 서비스를 추가할 때

다음 예시는 환불 서비스가 결제 계정과 VPC를 공유한다는 가정입니다. 거버넌스 저장소에서 실행합니다. 등록 PR을 승인한 뒤 도메인 checkout에 다시 export하면 기존 결제·정산의 환경 설정과 버전 핀을 보존하면서 환불 루트가 추가됩니다.

```bash
python3 scripts/new-service.py register 04_REFUNDS --domain payments \
  --targets payments-dev payments-stg payments-prod
python3 scripts/catalog.py
```

도메인 팀은 `services/01_PAYMENTS/dev/main.tf`에서 공통 모듈 SHA를 변경해 검증한 후 같은 SHA를 stg와 prod 순으로 승격합니다. 계정·상태·VPC 소유자 변경은 별도의 이전 작업으로 리뷰합니다. Terraform 상태가 이미 있는 서비스는 원래 S3 버킷·키와 리소스 주소를 확인하고 새 실행 경로의 plan을 비교합니다. [등록·재실행·이전 절차](service-template/README.md) · [기존 AWS 계정 편입](platform/README.md) · [S3 상태 버킷 준비](platform/state/README.md)

## GitHub 운영 기준과 검증

- `CODEOWNERS.example`을 실제 조직·팀으로 바꾸고, [기본 브랜치 ruleset 예시](governance-template/main-review.json)를 GitHub에서 가져옵니다. 승인 수, 예외, 필수 CI 검사 등 조직 운영자가 설정할 항목은 [GitHub 운영 기준](docs/github-standards.md)에 정리했습니다.
- `python3 scripts/test-service-factory.py`는 카탈로그와 도메인 생성을, `python3 -m unittest discover -s service-template/tests`는 변경 대상 선택을 검증합니다.
- 키트를 커밋한 뒤 `bash tests/repository-boundaries.sh`를 실행하면 임시 Git 저장소에서 라이브러리·거버넌스 추출, 결제 도메인 생성, 단일 변경 경로 선택, 잠긴 provider를 사용하는 Terraform 검증을 확인합니다. AWS 인증 없이 실행할 수 있으며 Terraform provider 다운로드 경로 또는 로컬 미러가 필요합니다.

## Terraform Enterprise와 Ansible 운영

- Terraform Enterprise를 사용하는 경우에도 GitHub 도메인 저장소를 유지하고 각 서비스·환경을 별도 workspace에 연결할 수 있습니다. AXA·Deutsche Bank 사례, HCP Terraform과의 선택 기준, 결제 dev의 상태 이전 절차를 정리했습니다. 현재 키트의 실행 구성은 Terraform CLI와 S3입니다. [실행 플랫폼 선택과 전환](docs/terraform-enterprise.md)
- EC2의 서비스 코드·환경·역할 태그로 현재 접속 대상을 조회하고, 배포에 사용하는 제어 노드에서 SSH와 원격 Python 실행을 점검할 수 있습니다. [도메인별 Ansible 인벤토리와 일일 점검](docs/ansible-inventory.md)
