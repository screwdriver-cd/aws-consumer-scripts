variable "sd_broker_endpointsvc_map" {
  type        = map(list(string))
  description = "Map of list of Screwdriver broker name and endpoint service"
  validation {
    condition = (
      length(var.sd_broker_endpointsvc_map) >= 2
    )
    error_message = "The broker endpoint-service map must be 2."
  }
}
variable "sd_broker_endpointsvc_port" {
  type    = string
  default = "9096"
}
variable "route53_zone_name" {
  type        = string
  description = "Name of route53 zone"
  validation {
    condition = (
      var.route53_zone_name != ""
    )
    error_message = "The route53_zone_name cannot be null."
  }
}
variable "consumer_fn_name" {
  type        = string
  description = "Name of consumer function"
  default = "screwdriver-consumer-svc"
}
variable "consumer_bucket_prefix" {
  type = string
  description = "S3 Bucket name prefix of the consumer build bucket named as prefix-accountId-regionShortName"
  default = "screwdriver-consumer-builds"
}
variable "tags" {
  type = map(string)
  default = {
    PRODUCT : "SCREWDRIVER"
    ENVIRONMENT : "prod"
    SERVICE : "screwdriver/consumer"
  }
}
variable "kms_key_arn" {
  type = string
  description = "KMS key for build encryption"
}

// if create new screwdriver vpc is true
variable "vpc_id" {
  type        = string
  description = "VPC ID where consumer function will be created"
  default = ""
}
variable "cidr_block" {
  default = "10.10.104.0/22"
  type    = string
}
variable "azs" {
  default = ["us-west-2a", "us-west-2b", "us-west-2c", "us-west-2d"]
  type    = list(string)
}
variable "private_subnets" {
  default = ["10.10.104.0/25", "10.10.104.128/25", "10.10.105.0/25", "10.10.105.128/25"]
  type    = list(string)
  validation {
    condition = (
      length(var.private_subnets) >= 2
    )
    error_message = "The private_subnets must be for each az."
  }
}
variable "public_subnets" {
  default = ["10.10.106.0/25", "10.10.106.128/25", "10.10.107.0/25", "10.10.107.128/25"]
  type    = list(string)
  validation {
    condition = (
      length(var.public_subnets) >= 2
    )
    error_message = "The public_subnets must be for each az when creating new vpc."
  }
}
variable "vpc_name" {
  type    = string
  default = "screwdriver-consumer"
}

// if create new build vpc is true
variable "build_vpc_id" {
  type        = string
  description = "VPC ID where consumer builds will run"
  default = ""
}
variable "build_cidr_block" {
  default = "172.21.104.0/22"
  type    = string
}
variable "build_azs" {
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
  type    = list(string)
}
variable "build_private_subnets" {
  default = ["172.21.104.0/25", "172.21.104.128/25", "172.21.105.0/25", "172.21.105.128/25"]
  type    = list(string)
  validation {
    condition = (
      length(var.build_private_subnets) >= 2
    )
    error_message = "The private_subnets must be for each az."
  }
}
variable "build_public_subnets" {
  default = ["172.21.106.0/25", "172.21.106.128/25", "172.21.107.0/25", "172.21.107.128/25"]
  type    = list(string)
  validation {
    condition = (
      length(var.build_public_subnets) >= 2
    )
    error_message = "The public_subnets must be for each az when creating new vpc."
  }
}
variable "build_vpc_name" {
  type    = string
  default = "screwdriver-consumer-builds"
}

variable "sd_broker_secret_arn" {
  type    = string
  description = "ARN of the AWS SecretManager secret value"
}

variable "kafka_topic" {
  type    = string
  description = "The kafka topic name"
}

variable "msk_cluster_arn" {
  type    = string
  default = ""
  description = "The MSK cluster arn if running in same account"
}
variable "ecr_name" {
  type    = string
  default = "screwdriver-hub"
  description = "The ECR account name for housing the build docker images"
}
variable "create_ecr" {
  type    = bool
  default = false
  description = "Set to true if creating a AWS ECR"
}
variable "consumer_role_arn" {
   type    = string
   default = ""
   description = "The Build IAM Role Arn for ECR permissions"
}
variable "create_build_vpc" {
  type    = bool
  default = false
  description = "Set to true if running build in separate region and/or vpc"
}
variable "sd_build_kms_key_alias" {
  type    = string
  default = "alias/screwdriver-builds-key"
  description = "The Screwdriver Builds KMS Key alias name"
}
variable "aws_region" {
  type = string
  default = "us-west-2"
  description = "Region name for the AWS account where service will be provisioned"
}
variable "build_region" {
  type = string
  default = "us-west-2"
  description = "Region name for the AWS account where builds will run"
}
variable "tf_backend_bucket" {
  type = string
  description = "The tf backend bucket"
}

variable "create_service_role" {
  type = bool
  default = false
  description = "Flag to create builds service role with codebuild permissions"
}
variable "build_role_name"{
  type = string
  default = "screwdriver-builds-role"
  description = "Name of the role for running builds"
}

variable "user_aws_account_id" {
  type = string
  description = "User AWS account ID"
}
variable "create_build_sg" {
  type =  bool
  default = true
  description = "Create security group in build region"
}