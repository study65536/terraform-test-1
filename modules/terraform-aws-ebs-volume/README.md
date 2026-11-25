# terraform-aws-ebs-volume

암호화된 gp3 볼륨을 만들고 선택한 EC2에 연결합니다.

플랫폼 소스를 체크아웃한 저장소 루트에서 조합하는 예시입니다.

```hcl
module "data" {
  source = "./modules/terraform-aws-ebs-volume"

  name              = "payments-dev-data"
  availability_zone = module.web.availability_zone
  size_gib          = 50
  attachment        = { instance_id = module.web.instance_id }
  final_snapshot    = true
}
```

`volume_id`와 `volume_arn`을 반환합니다. 인스턴스와 같은 AZ를 선택하고 파일 시스템 초기화·마운트는 호스트 구성에서 수행합니다. [AWS EBS 볼륨 연결](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-attaching-volume.html)

[모든 입력](variables.tf) · [모든 출력](outputs.tf)
