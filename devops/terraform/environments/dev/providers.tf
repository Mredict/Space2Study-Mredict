provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Space2Study"
      Environment = "prod"
      ManagedBy   = "Terraform"
    }
  }
}