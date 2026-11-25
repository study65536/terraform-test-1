output "resources" {
  description = "환경에 생성된 리소스 식별자와 EC2 사설 IP"
  value = {
    vpc_id         = local.vpc_id
    instances      = { for name, vm in module.ec2_instance : name => { id = vm.instance_id, private_ip = vm.private_ip } }
    data_volumes   = { for name, disk in module.ebs_volume : name => disk.volume_id }
    bucket         = one(module.s3_bucket[*].bucket_name)
    ecr_repository = one(module.ecr[*].repository_url)
    eks_cluster    = local.eks_cluster_name
    efs_dns_name   = one(module.efs[*].dns_name)
  }
}

output "private_subnet_ids_by_az" {
  description = "서비스별 모듈(RDS 등)을 연결할 프라이빗 서브넷"
  value       = local.private_subnet_ids_by_az
}

output "alb_dns_name" {
  value = one(module.internal_alb[*].dns_name)
}

output "gateway_endpoint_ids" {
  value = module.gateway_endpoints.gateway_endpoint_ids
}
