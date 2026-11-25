# Preserve state addresses from the original workload stack.
moved {
  from = module.network
  to   = module.vpc
}

moved {
  from = module.ec2
  to   = module.ec2_instance
}

moved {
  from = module.ebs
  to   = module.ebs_volume
}

moved {
  from = module.s3
  to   = module.s3_bucket
}

# Existing managed networks remain the first VPC module instance.
moved {
  from = module.vpc
  to   = module.vpc[0]
}
