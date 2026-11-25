variable "service_code" {
  type        = string
  description = "리소스 이름과 태그에 쓰는 카탈로그의 서비스 코드"
}

variable "environment" {
  type        = string
  description = "dev, stg 또는 prod"
}

variable "account_id" {
  type        = string
  description = "버킷 이름에 포함할 대상 AWS 계정 번호"
}

variable "region" {
  type        = string
  description = "서비스 환경의 AWS 리전"
}

variable "workload" {
  description = "운영자가 Git에서 관리하는 서비스 환경 사양"
  type = object({
    vpc_cidr                  = string
    availability_zones        = list(string)
    shared_network_owner_code = optional(string)
    shared_eks_cluster_name   = optional(string)
    nat_gateway_per_az        = optional(bool, false)
    gateway_endpoints         = optional(set(string), [])
    flow_log = optional(object({
      destination_arn     = string
      traffic_type        = optional(string, "ALL")
      aggregation_seconds = optional(number, 600)
    }))
    alb = optional(object({
      certificate_arn  = string
      client_cidrs     = set(string)
      target_instances = set(string)
      target_port      = optional(number, 80)
      health_path      = optional(string, "/healthz")
    }))
    enable_bucket      = optional(bool, true)
    enable_registry    = optional(bool, true)
    ssh_source_sg_id   = optional(string)
    https_egress_cidrs = optional(set(string), [])
    instances = optional(map(object({
      ami_id               = string
      availability_zone    = string
      role                 = string
      instance_type        = optional(string, "t3.micro")
      key_name             = optional(string)
      iam_instance_profile = optional(string)
      data_disk_gib        = optional(number)
    })), {})
    enable_efs = optional(bool, false)
    eks = optional(object({
      kubernetes_version  = string
      admin_principal_arn = string
      api_client_sg_id    = optional(string)
    }))
  })

  validation {
    condition     = alltrue([for service in var.workload.gateway_endpoints : contains(["s3", "dynamodb"], service)])
    error_message = "Gateway endpoints can be s3 or dynamodb."
  }

  validation {
    condition = var.workload.alb == null ? true : (
      length(var.workload.alb.target_instances) > 0 &&
      length(setsubtract(var.workload.alb.target_instances, keys(var.workload.instances))) == 0 &&
      length(var.workload.alb.client_cidrs) > 0 &&
      alltrue([for cidr in var.workload.alb.client_cidrs : can(cidrnetmask(cidr))])
    )
    error_message = "Supply existing instance keys and allowed IPv4 client networks for the ALB."
  }

  validation {
    condition = (
      can(cidrnetmask(var.workload.vpc_cidr)) &&
      endswith(var.workload.vpc_cidr, "/20") &&
      length(var.workload.availability_zones) >= 2 &&
      length(var.workload.availability_zones) <= 8 &&
      length(distinct(var.workload.availability_zones)) == length(var.workload.availability_zones)
    )
    error_message = "이 스택은 IPv4 /20 VPC와 중복 없는 가용 영역 2~8개를 사용합니다."
  }

  validation {
    condition = alltrue([
      for instance in values(var.workload.instances) :
      contains(var.workload.availability_zones, instance.availability_zone) &&
      can(regex("^ami-[0-9a-f]{17}$", instance.ami_id))
    ])
    error_message = "각 EC2에는 현재 리전의 AMI ID와 VPC가 포함하는 가용 영역이 필요합니다."
  }

  validation {
    condition     = alltrue([for cidr in var.workload.https_egress_cidrs : can(cidrnetmask(cidr))])
    error_message = "https_egress_cidrs에는 패키지 저장소 또는 프록시에 도달할 수 있는 IPv4 CIDR을 지정하세요."
  }

  validation {
    condition     = !var.workload.enable_efs || length(var.workload.instances) > 0 || var.workload.eks != null || var.workload.shared_eks_cluster_name != null
    error_message = "EFS를 사용하려면 EC2 또는 EKS 클라이언트를 정의하세요."
  }

  validation {
    condition = var.workload.shared_network_owner_code == null ? true : (
      var.workload.shared_network_owner_code != var.service_code &&
      !var.workload.nat_gateway_per_az && var.workload.flow_log == null &&
      length(var.workload.gateway_endpoints) == 0 && var.workload.eks == null
    )
    error_message = "공유 네트워크의 NAT, Flow Logs, 엔드포인트 및 EKS 클러스터는 소유 루트에서 설정하세요."
  }

  validation {
    condition     = var.workload.shared_eks_cluster_name == null || var.workload.eks == null
    error_message = "기존 EKS 이름과 신규 EKS 생성 설정 중 하나를 선택하세요."
  }

  validation {
    condition     = var.workload.eks == null || var.workload.nat_gateway_per_az
    error_message = "이 스택의 프라이빗 EKS 노드가 AWS 서비스에 접근하려면 nat_gateway_per_az를 켜세요."
  }
}
