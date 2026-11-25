terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    key          = "platform/control-tower/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.admin_account_id]
}

variable "admin_account_id" {
  description = "플랫폼 루트 실행 역할이 있는 AWS 계정 ID"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.admin_account_id))
    error_message = "실행 대상 AWS 계정 ID 12자리를 입력하세요."
  }
}

variable "region" {
  description = "해당 플랫폼 서비스가 구성된 AWS 리전"
  type        = string
}
