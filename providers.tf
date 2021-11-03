terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  ## UnComment if using a local back to safe tf state file
  ## replace tf_backend_bucket and aws_region
  # backend "s3" {
  #   bucket = tf_backend_bucket
  #   key    = "sdawscnsumr"
  #   region = aws_region
  # }
  ## Uncomment if using a local backend to save tf state file
  # backend "local" {
  #   path = "relative/path/to/terraform.tfstate"
  # }
}
provider "aws" {}
