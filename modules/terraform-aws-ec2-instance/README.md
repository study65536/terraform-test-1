# terraform-aws-ec2-instance

서비스의 AMI를 사설 서브넷에 배포합니다. 인스턴스는 IMDSv2 토큰과 암호화된 gp3 루트 디스크를 사용합니다.

플랫폼 소스를 체크아웃한 저장소 루트에서 조합하는 예시입니다.

```hcl
module "web" {
  source = "./modules/terraform-aws-ec2-instance"

  name               = "payments-dev-web-01"
  ami_id             = var.ami_id
  instance_type      = "t3.micro"
  subnet_id          = module.vpc.private_subnet_ids_by_az["ap-northeast-2a"]
  security_group_ids = [module.web_sg.security_group_id]
}
```

`instance_id`, `private_ip`, `availability_zone`을 반환합니다. SSH에는 `key_name`과 제어 노드로부터의 라우팅·SG가, Systems Manager에는 `iam_instance_profile`과 SSM Agent 및 AWS API 경로가 필요합니다. [AWS EC2 메타데이터 옵션](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-options.html)

[모든 입력](variables.tf) · [모든 출력](outputs.tf)
