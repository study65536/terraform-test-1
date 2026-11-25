# terraform-aws-eks

EKS 제어 영역, 관리형 노드 그룹, IAM 역할, 프라이빗 API 엔드포인트 및 관리자 액세스 엔트리를 구성합니다.

플랫폼 소스를 체크아웃한 저장소 루트에서 조합하는 예시입니다.

```hcl
module "cluster" {
  source = "./modules/terraform-aws-eks"

  name                = "payments-dev"
  kubernetes_version  = var.supported_eks_version
  subnet_ids_by_az    = module.vpc.private_subnet_ids_by_az
  admin_principal_arn = var.eks_admin_role_arn
}
```

`cluster_name`, `cluster_endpoint`, `cluster_security_group_id`가 출력됩니다. 데이터 플레인에는 ECR·S3 등 노드 부팅에 필요한 서비스 경로, 운영자에게는 프라이빗 API까지 라우팅과 접근 권한이 필요합니다. [EKS 프라이빗 클러스터](https://docs.aws.amazon.com/eks/latest/userguide/private-clusters.html)

[모든 입력](variables.tf) · [모든 출력](outputs.tf)
