# infra-as-code/terraform/sample-aws/versions.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30.0" # Or a newer 5.x version if available and compatible
    }
  }
}
