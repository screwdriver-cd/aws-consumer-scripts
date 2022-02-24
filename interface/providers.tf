
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  ## Uncomment if using a local backend to save tf state file
  ## replace tf_backend_bucket and aws_region
  backend "s3" {}
  #  bucket = var.tf_backend_bucket
  #  key    = "vespa-consumerinterface.tfstate"
  #  region = var.aws_region
  #}
  ## Uncomment if using a local backend to save tf state file
  # backend "local" {
  #   path = "relative/path/to/terraform.tfstate"
  # }
}
provider "aws" {
  region = var.aws_region
}