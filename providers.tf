terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  ## update variables tf_backend_bucket and aws_region
  backend "s3" {}
  #  bucket = "340272556944-aws-integration-tfstate"
  #  key    = "vespa-consumer.tfstate"
  #  region = "us-west-2"
  #}
  ## Uncomment if using a local backend to save tf state file
  # backend "local" {
  #   path = "relative/path/to/terraform.tfstate"
  # }
}
provider "aws" {
  region = var.aws_region
}
    
provider "aws" {
  region = var.build_region
  alias = "build"
}