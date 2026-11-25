variable "name" {
  description = "EKS 클러스터 이름"
  type        = string
  nullable    = false
}

variable "kubernetes_version" {
  description = "배포 리전에서 지원하는 EKS Kubernetes 마이너 버전"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.kubernetes_version))
    error_message = "kubernetes_version은 1.로 시작하는 마이너 버전 문자열이어야 합니다."
  }
}

variable "subnet_ids_by_az" {
  description = "클러스터와 관리형 노드에 사용할 같은 VPC의 프라이빗 서브넷 ID 맵. 가용 영역 이름을 키로 사용합니다."
  type        = map(string)
  nullable    = false

  validation {
    condition     = length(var.subnet_ids_by_az) >= 2
    error_message = "EKS에는 서로 다른 가용 영역의 서브넷이 두 개 이상 필요합니다."
  }
}

variable "admin_principal_arn" {
  description = "EKS 클러스터 관리자 액세스를 부여할 IAM 역할 또는 IAM 사용자 ARN"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:iam::[0-9]{12}:(role|user)/.+$", var.admin_principal_arn))
    error_message = "admin_principal_arn에는 IAM 역할 또는 IAM 사용자 ARN을 지정하세요."
  }
}

variable "public_access_cidrs" {
  description = "Kubernetes API 공개 엔드포인트 접근을 허용할 CIDR. 기본값은 프라이빗 엔드포인트만 사용합니다."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for cidr in var.public_access_cidrs : can(cidrhost(cidr, 0))])
    error_message = "public_access_cidrs의 각 값은 유효한 CIDR이어야 합니다."
  }
}

variable "node_group" {
  description = "AL2023 x86_64 관리형 노드 그룹의 인스턴스 유형, 용량, 노드 개수, 루트 디스크 크기"
  type = object({
    instance_types = optional(list(string), ["m6i.large"])
    capacity_type  = optional(string, "ON_DEMAND")
    min_size       = optional(number, 2)
    desired_size   = optional(number, 2)
    max_size       = optional(number, 4)
    disk_size_gib  = optional(number, 40)
  })
  default  = {}
  nullable = false

  validation {
    condition     = length(var.node_group.instance_types) >= 1 && length(var.node_group.instance_types) <= 20
    error_message = "instance_types에 x86_64 인스턴스 유형을 1~20개 지정하세요."
  }

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_group.capacity_type)
    error_message = "capacity_type은 ON_DEMAND 또는 SPOT이어야 합니다."
  }

  validation {
    condition = (
      var.node_group.min_size >= 0 &&
      var.node_group.max_size >= 1 &&
      var.node_group.min_size <= var.node_group.desired_size &&
      var.node_group.desired_size <= var.node_group.max_size &&
      alltrue([
        for size in [var.node_group.min_size, var.node_group.desired_size, var.node_group.max_size] :
        floor(size) == size
      ])
    )
    error_message = "노드 수는 정수여야 하며 0 <= min_size <= desired_size <= max_size와 max_size >= 1을 만족해야 합니다."
  }

  validation {
    condition     = var.node_group.disk_size_gib >= 20 && floor(var.node_group.disk_size_gib) == var.node_group.disk_size_gib
    error_message = "disk_size_gib는 20 이상의 정수여야 합니다."
  }
}

variable "tags" {
  description = "AWS 프로바이더 공통 태그에 더할 태그"
  type        = map(string)
  default     = {}
  nullable    = false
}
