provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "AICorp"
      Environment = "bootstrap"
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = "platform-engineering"
    }
  }
}
