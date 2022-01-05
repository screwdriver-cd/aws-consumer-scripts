terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  ## Uncomment if using a local backend to save tf state file
  ## replace tf_backend_bucket and aws_region
  backend "s3" {
    bucket = "932577692850-aws-integration-tfstate"
    key    = "sdawscnsumr"
    region = "us-east-2"
  }
  ## Uncomment if using a local backend to save tf state file
  # backend "local" {
  #   path = "relative/path/to/terraform.tfstate"
  # }
}
provider "aws" {}
