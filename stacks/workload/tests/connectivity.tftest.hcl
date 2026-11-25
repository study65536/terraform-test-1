mock_provider "aws" {}

variables {
  service_code = "payments"
  environment  = "dev"
  account_id   = "111111111101"
  region       = "ap-northeast-2"
  workload = {
    vpc_cidr           = "10.10.0.0/20"
    availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]
  }
}

run "existing_specs_keep_connectivity_opt_in" {
  command = plan
  assert {
    condition     = length(module.internal_alb) == 0 && length(output.gateway_endpoint_ids) == 0
    error_message = "Existing workload specs must not acquire an ALB or gateway endpoint by default."
  }
}

run "web_tier_with_s3_endpoint" {
  command = plan
  variables {
    workload = {
      vpc_cidr           = "10.10.0.0/20"
      availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]
      gateway_endpoints  = ["s3"]
      instances = {
        web = { ami_id = "ami-0123456789abcdef0", availability_zone = "ap-northeast-2a", role = "web" }
      }
      alb = {
        certificate_arn  = "arn:aws:acm:ap-northeast-2:111111111101:certificate/00000000-0000-0000-0000-000000000001"
        target_instances = ["web"]
        client_cidrs     = ["10.80.0.0/16"]
      }
    }
  }
  assert {
    condition     = length(module.internal_alb) == 1 && contains(keys(output.gateway_endpoint_ids), "s3") && contains(keys(output.resources.instances), "web")
    error_message = "The selected ALB, EC2 instance and S3 gateway endpoint must be present in the plan."
  }
}

run "consumer_reads_shared_resources" {
  command = plan
  variables {
    service_code = "settlement"
    workload = {
      vpc_cidr                  = "10.10.0.0/20"
      availability_zones        = ["ap-northeast-2a", "ap-northeast-2c"]
      shared_network_owner_code = "payments"
      shared_eks_cluster_name   = "payments-dev"
    }
  }
  override_data {
    target = data.aws_vpc.shared
    values = {
      id         = "vpc-0123456789abcdef0"
      cidr_block = "10.10.0.0/20"
    }
  }
  override_data {
    target = data.aws_eks_cluster.shared
    values = {
      vpc_config = [{
        vpc_id                    = "vpc-0123456789abcdef0"
        cluster_security_group_id = "sg-0123456789abcdef0"
      }]
    }
  }
  assert {
    condition     = length(module.vpc) == 0 && length(module.eks) == 0 && length(data.aws_subnet.shared) == 2
    error_message = "공유 소비자 루트는 지정된 AZ의 서브넷을 조회하고 VPC와 EKS 생성은 소유 팀에 맡깁니다."
  }
}
