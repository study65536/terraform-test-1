# 도메인 저장소에서 EC2 인벤토리와 SSH 연결 점검하기

결제 도메인의 `01_PAYMENTS/dev`와 `03_SETTLEMENT/dev`는 같은 AWS 계정과 VPC를 사용합니다. 도메인 저장소의 `services/01_PAYMENTS/dev/account.json`에서 조회할 계정·리전을 찾고, EC2 태그에서 실제 서버 목록을 얻습니다. EC2에는 `ServiceCode`, `Environment`, `Owner`, `ManagedBy`와 `instances`에 지정한 `Role`이 붙습니다. 결제 웹 서버는 `ServiceCode=payments`, `Environment=dev`, `Role=web`으로 선택합니다. [계정·도메인 매핑](../catalog/README.md) · [워크로드 입력 예](../examples/services/README.md)

## 결제 dev 인벤토리

제어 노드에는 Python 3.12 가상환경, `ansible-core>=2.21,<2.22`, `amazon.aws` 컬렉션 12.x 및 같은 가상환경의 `boto3`·`botocore`가 필요합니다. 아래 YAML을 도메인 저장소의 `inventories/payments-dev.aws_ec2.yml`로 저장합니다. 캐시를 끄면 실행 시점의 인스턴스 ID와 사설 IP를 조회합니다. 계정의 실행 중인 웹 서버가 0대면 그룹도 비게 됩니다. [EC2 인벤토리 플러그인과 SDK 요구 사항](https://docs.ansible.com/projects/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html) · [Ansible Python 지원표](https://docs.ansible.com/projects/ansible/latest/reference_appendices/release_and_maintenance.html)

```yaml
plugin: amazon.aws.aws_ec2
regions: [ap-northeast-2]
cache: false
filters:
  instance-state-name: running
  "tag:ManagedBy": Terraform
  "tag:Environment": dev
  "tag:ServiceCode": payments
  "tag:Role": web
hostnames: [instance-id]
compose:
  ansible_host: private_ip_address
groups:
  web: ec2_tags.Role == 'web'
```

제어 노드에서 EC2 조회 역할로 인증하고 사설 IP까지 라우팅이 되는지 확인합니다. 이 스택의 EC2는 공인 IP를 받지 않습니다. SSH 키 인증을 쓰면 대상에 해당 키 페어의 `key_name`을 설정하고, `ssh_source_sg_id`에 네트워크에서 참조 가능한 제어 노드의 보안 그룹을 지정해 TCP 22를 허용합니다. 기본 사양은 인스턴스 0대이며 키와 SSH 허용 규칙은 선택 사항입니다. 조회용 IAM 권한, OS 로그인 권한, Nginx 설치용 sudo 권한은 별도로 부여합니다. [AWS 보안 그룹 규칙](https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html)

아래는 제어 노드에 결제 도메인 저장소를 체크아웃하고 `AWS_PROFILE`과 키 경로를 준비한 경우입니다. **예시는 Amazon Linux 2023 AMI와 `ec2-user`를 가정**합니다. Terraform은 환경별 AMI ID를 사용하므로 다른 이미지에는 해당 사용자를 지정합니다. 운영에서 확인한 SSH 호스트 키는 제어 노드의 `known_hosts`로 관리합니다. [AL2023 시스템 Python](https://docs.aws.amazon.com/linux/al2023/ug/python.html)

```bash
export AWS_PROFILE=payments-dev
export ANSIBLE_PRIVATE_KEY_FILE="$HOME/.ssh/payments-dev.pem"
inventory=inventories/payments-dev.aws_ec2.yml

(
  set -eu
  expected=$(python3 -c 'import json; print(json.load(open("services/01_PAYMENTS/dev/account.json"))["account_id"])')
  test "$(aws sts get-caller-identity --query Account --output text)" = "$expected"
  ansible-inventory -i "$inventory" --graph
  ansible -i "$inventory" web --list-hosts
  ansible -i "$inventory" web -u ec2-user -m ansible.builtin.ping -f 10
  ansible -i "$inventory" web -u ec2-user -m ansible.builtin.setup -a 'filter=ansible_distribution*'
)
```

`pong`은 그 제어 노드의 SSH 인증과 원격 Python 실행이 성공했다는 결과입니다. 마지막 명령은 서버가 보고하는 OS 배포판과 버전을 수집합니다. 기존 Amazon Linux 2023 Nginx 플레이북을 사용할 때에도 같은 인벤토리와 `--limit web`을 지정하고, 해당 플레이북의 HTTP `/healthz` 검사로 서비스 응답을 확인합니다. [SSH·Python 점검 모듈](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/ping_module.html) · [OS 정보 수집 모듈](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/setup_module.html)

## 여러 계정의 일일 보고

300개 AWS 계정을 점검한다면 카탈로그에서 중복을 제거한 계정·리전별로 읽기 역할과 실행 경로를 정하고, 해당 네트워크에서 접근 가능한 제어 노드에 작업을 배정합니다. 각 계정은 소유 팀, 서비스, 환경, 인스턴스 ID, OS 버전, 마지막 성공 시각과 실패 원인을 보고합니다. 계정 조회 오류와 미응답 호스트를 따로 기록하고, 자산 원장 또는 해당 환경의 `workload.json`과 대조해 **예상·조회·SSH 성공 대수**를 집계합니다. 예를 들어 예상 5대 중 4대만 검색돼 모두 응답했다면 태그와 나머지 한 대의 상태를 점검합니다.

매일 점검하려면 사설망에 연결된 제어 노드에서 위 절차를 예약하고, 각 배포 직전에도 해당 서비스·환경만 다시 확인합니다. 서비스 수와 계정 수는 독립적이며, 같은 계정의 결제·정산 서버는 서비스 태그로 구분합니다. [Ansible 인벤토리와 호스트 그룹](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html)
