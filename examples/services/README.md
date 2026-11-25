# 서비스 팀의 환경별 워크로드 입력

결제·주문 예제의 각 환경에는 `workload.json` 입력이 있습니다. 카탈로그의 계정·주소 할당과 이 파일들을 조합하면 팀 저장소를 만들 수 있습니다. 정산 등 별도 입력 예시가 없는 서비스는 빈 컴퓨팅 구성에서 시작하고, 루트의 account.json에 기록된 대상·네트워크 소유자를 사용합니다. 생성 후 서비스 팀이 자기 저장소의 입력을 수정합니다. [팀 저장소 생성과 실행](../../service-template/README.md)

기본 구성에는 두 AZ의 VPC·서브넷·라우팅, 서비스 데이터용 S3 버킷, ECR 저장소가 포함됩니다. 서비스 팀은 필요한 환경에서 EC2, 데이터 볼륨, EFS, EKS 등을 추가합니다. VPC CIDR 및 AZ는 플랫폼 카탈로그의 계정별 할당값을 사용합니다. AZ 순서를 변경하면 서브넷 교체가 계획될 수 있습니다.

## EC2 한 대와 영구 데이터 디스크 추가

아래는 `workload.json`에서 갱신할 속성 예시입니다. 실제 AMI, 배포 계정의 EC2 키 페어 이름, 제어 서버 보안 그룹으로 바꿉니다. 스택은 `instances`의 키로 리소스를 추적하므로 `web-01`을 유지하면서 다른 서버를 추가할 수 있습니다.

```json
{
  "nat_gateway_per_az": false,
  "ssh_source_sg_id": "sg-0123456789abcdef0",
  "https_egress_cidrs": ["10.200.0.16/32"],
  "instances": {
    "web-01": {
      "ami_id": "ami-0123456789abcdef0",
      "availability_zone": "ap-northeast-2a",
      "instance_type": "t3.micro",
      "role": "web",
      "key_name": "payments-dev-ansible",
      "data_disk_gib": 20
    }
  },
  "enable_efs": true
}
```

EC2는 프라이빗 서브넷을 사용합니다. 이 예시의 제어 서버는 웹 서버 보안 그룹에서 참조할 수 있는 SG와 사설 라우팅 경로가 필요합니다. HTTPS 송신은 `https_egress_cidrs`에 등록한 목적지로 제한합니다. 예시 주소는 실제로 라우팅되는 패키지 미러 또는 HTTPS 프록시 주소로 교체하세요. 인터넷 미러를 사용하는 경우 해당 목적지 CIDR을 허용하고 이 스택의 NAT 옵션을 켭니다. AZ별 NAT 게이트웨이에는 시간·처리량 비용이 발생합니다. EFS를 켜면 스택은 EFS 보안 그룹으로 향하는 NFS 송신 규칙도 추가합니다. 태그 `ServiceCode=payments`, `Environment=dev`, `Role=web`로 Ansible 인벤토리를 구성할 수 있습니다. [AWS Terraform 코드 구성과 보안 그룹 설계](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/structure.html)

`data_disk_gib`를 지정하면 같은 AZ의 암호화된 gp3 데이터 볼륨이 붙습니다. 파일 시스템 생성과 마운트는 인스턴스 구성 단계에서 수행합니다. `enable_efs`를 켜면 각 AZ에 NFS 마운트 대상이 생기고, 스택은 클라이언트 보안 그룹의 TCP 2049 연결을 허용합니다.

## EKS를 사용하는 서비스

`eks`를 객체로 지정하고 `nat_gateway_per_az`를 켭니다. `kubernetes_version` 값은 대상 리전에서 확인한 마이너 버전으로, `admin_principal_arn`은 사전에 준비한 운영 관리자 역할 ARN으로 채웁니다.

```bash
aws eks describe-cluster-versions --region ap-northeast-2 --version-status STANDARD_SUPPORT \
  --query 'clusterVersions[].{Version:clusterVersion,SupportEnds:endOfStandardSupportDate}' --output table
```

표준 지원 기간, Kubernetes 애드온 호환성, 노드 AMI를 함께 확인합니다. 이 저장소는 기존 모듈과 호환을 위해 AWS provider 5.100.0을 잠급니다. 새 EKS API 기능에 더 높은 provider 버전이 필요하면 별도 PR에서 루트의 버전 제약과 잠금 파일을 갱신하고 dev에서 클러스터·노드 계획과 등록을 점검한 뒤 승격합니다. [Amazon EKS 버전 수명 주기](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) · [AWS CLI 버전 조회](https://docs.aws.amazon.com/cli/latest/reference/eks/describe-cluster-versions.html) · [AWS provider 버전 관리](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/version.html)

```json
{
  "nat_gateway_per_az": true,
  "eks": {
    "kubernetes_version": "<지원되는 1.x 마이너 버전>",
    "admin_principal_arn": "arn:aws:iam::222222222201:role/EksOperations",
    "api_client_sg_id": "sg-0123456789abcdef0"
  }
}
```

이 조합은 프라이빗 API 엔드포인트, 두 AZ에 걸친 관리형 노드 그룹, 노드/클러스터 역할을 생성합니다. `api_client_sg_id`에는 클러스터에서 참조할 수 있는 운영 단말 또는 배포 러너의 보안 그룹을 지정합니다. TCP 443 허용과 별도로 해당 단말에서 프라이빗 엔드포인트까지의 라우팅·DNS가 필요합니다. EFS를 파드에서 사용하려면 CSI 드라이버와 워크로드 IAM 권한도 구성하세요. EKS와 NAT는 생성하는 시점부터 비용이 발생합니다.
