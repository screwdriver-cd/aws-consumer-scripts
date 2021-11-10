variable "vpc_id" {
  type        = string
  description = "VPC ID where consumer function will be created"
  default = null
}
variable "sd_broker_endpointsvc_map" {
  type        = map(list(string))
  description = "Map of list of Screwdriver broker name and endpoint service"
  validation {
    condition = (
      length(var.sd_broker_endpointsvc_map[0]) != 2
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
      var.route53_zone_name == null
    )
    error_message = "The route53_zone_name cannot be null."
  }
}
variable "consumer_fn_name" {
  type        = string
  description = "Name of consumer function"
  default = "screwdriver-consumer-svc"
}
variable "tags" {
  type = map(string)
  default = {
    PRODUCT : "SCREWDRIVER"
    ENVIRONMENT : "prod"
    SERVICE : "screwdriver/consumer"
  }
}

// if create new vpc is true
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
      length(var.private_subnets) < 3
    )
    error_message = "The private_subnets must be for each az."
  }
}
variable "public_subnets" {
  default = ["10.10.106.0/25", "10.10.106.128/25", "10.10.107.0/25", "10.10.107.128/25"]
  type    = list(string)
  validation {
    condition = (
      length(var.public_subnets) < 3
    )
    error_message = "The public_subnets must be for each az when creating new vpc."
  }
}
variable "vpc_name" {
  type    = string
  default = "screwdriver-consumer"
}
variable "sd_broker_secret_arn" {
  type    = string
  description = "ARN of the AWS SecretManager secret value"
}