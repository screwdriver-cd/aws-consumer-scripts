
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  backend "s3" {}
  ## Uncomment if using a local backend to save tf state file
  # backend "local" {
  #   path = "relative/path/to/terraform.tfstate"
  # }
}
provider "aws" {
  region = var.aws_region
}