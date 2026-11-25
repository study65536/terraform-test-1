# 도메인, 계정과 배포 대상

`accounts.json`의 네 영역을 결합해 서비스별 실행 루트를 생성합니다.

| 영역 | 소유하는 정보 |
|---|---|
| `domains` | 서비스 소유·배포 권한을 공유하는 도메인의 팀 이름 |
| `accounts` | 12자리 AWS 계정 ID와 계정 이름. 기존 IAM 할당을 가져올 때는 `assignment_key`로 이전 Terraform 주소의 접두사를 유지 |
| `targets` | AWS 계정, 환경, 리전, VPC 대역, 배정된 AZ, 네트워크를 소유하는 서비스 |
| `services` | 서비스 식별자, 소유 도메인, dev·stg·prod의 배포 대상 이름 |

`01_PAYMENTS/dev`와 `03_SETTLEMENT/dev`는 `payments-dev`를 참조합니다. 이 계정에서 VPC를 생성하는 루트는 `01_PAYMENTS/dev` 하나입니다. 정산 루트는 결제 VPC와 프라이빗 서브넷을 조회하고, 별도의 S3 키에 정산 리소스 상태를 기록합니다. 같은 계정에 할당된 그룹의 EC2 인벤토리 읽기 권한은 그 계정의 EC2 메타데이터 전체에 적용됩니다. 여러 서비스가 같은 계정·그룹 조합을 요청하면 Identity Center 할당은 한 건으로 합쳐집니다. [IAM Identity Center 계정 할당](https://docs.aws.amazon.com/singlesignon/latest/userguide/assignusers.html)

## 등록과 독립 저장소 출력

```bash
python3 scripts/new-service.py register 04_REFUNDS --domain payments \
  --targets payments-dev payments-stg payments-prod
python3 scripts/catalog.py
python3 scripts/new-service.py export payments --module-repo https://github.com/ORG/terraform-aws-library.git \
  --ref "$LIBRARY_SHA" --output ../payments-infra
```

`export`는 이미 출력한 도메인에 서비스를 추가할 때에도 사용합니다. 기존 환경별 SHA, Terraform 설정, 사용자 정의 파일과 CI는 그대로 둡니다. 실제 배포 계정, CIDR, 네트워크 소유자 등 할당이 바뀌면 해당 환경의 변경을 먼저 검토합니다. `python3 scripts/new-service.py account-map 04_REFUNDS dev`로 최신 `account.json`을 확인할 수 있습니다. 할당된 계정이나 S3 백엔드가 바뀌면 상태 이전 계획과 변경 전후의 plan을 확인합니다.

새 계정 및 VPC를 사용하는 도메인을 한 번에 등록할 수도 있습니다. 계정 ID는 AWS에서 이미 발급된 실제 값으로, /18은 사내 IPAM에서 배정한 값으로 교체합니다.

```bash
python3 scripts/new-service.py register 05_SEARCH --domain search --owner team-search \
  --accounts 333333333301 333333333302 333333333303 \
  --cidr 10.30.0.0/18 --azs ap-northeast-2a ap-northeast-2c
```

## 기존 카탈로그 이전

기존 예시 6개 계정의 ID·리전·CIDR·AZ와 `services/<기존 서비스>/<환경>/terraform.tfstate` 키는 유지했습니다. 이전 `01_PAYMENTS`의 세 환경은 도메인 `payments`와 `payments-{dev,stg,prod}` 대상으로, `02_ORDERS`는 도메인 `orders`와 `orders-{dev,stg,prod}` 대상으로 매핑됩니다. 각각의 네트워크 소유자는 기존 서비스와 같습니다. 새 `03_SETTLEMENT`에는 결제 도메인·대상을 배정했습니다. 기존 Identity Center 계정의 `assignment_key`에는 기존 상태 주소와 동일하게 `01_PAYMENTS/dev` 등의 값을 넣습니다. 이미 배포된 할당의 키를 변경하기 전에는 IAM 상태 이동을 계획하세요. 실제 운영 카탈로그 이전도 이 매핑과 동일한 순서로 계정·대상·서비스를 등록하고 기존 루트별 첫 plan을 점검합니다.
