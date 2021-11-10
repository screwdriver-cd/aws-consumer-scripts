# Screwdriver AWS Integration Consumer Service Scripts
Infrastructure-as-code script for onboarding to Screwdriver AWS Integration

## Introduction

This repository is meant to serve as an install/uninstall/update script to provision necessary cloud infrastructure resources required for Screwdriver AWS Integration. The following are the resources created by the installation script by default:
- 3 AWS VPC Endpoint Interface (1 for each availability zone)
- 1 AWS Route 53 Private Hosted Zone
- 3 AWS Route 53 Alias Records for each VPC Endpoint Interface
- 1 AWS Lambda as Screwdriver Consumer Service
- 1 AWS Lambda Kafka Event Source pointing to Alias Records
- 1 Security Group For AWS Lambda and VPC Interface

Additionally, if you opt for a new VPC creation, it will create all the required VPC infrastructure
- 1 VPC based on the provided CIDR block
- Private subnets
- Public subnets
- NAT Gateway
- Internet Gateway
- Route Table

This script uses open source tool [terraform](https://www.terraform.io/) to provision all the resources

### Dependencies

The followings are the external dependencies required to run this onboarding script:

- [terraform](https://github.com/hashicorp/terraform/releases/latest)
- [wget](https://www.gnu.org/software/wget/)
- [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

All of these tools can be installed via Homebrew on Mac OS X.

## Prerequisite
To start using Screwdriver on your AWS account, please reach out to the Screwdriver Team and get the list of broker endpoints and the corresponding route53 zone name. Also a Amazon Secret Manager secret needs to be created manually (for now), the values for which will be provided by Screwdriver Team. 

## Instructions

To get started, update the var file with the required details. Please refer to [`setup.tfvars`](./setup.tfvars) for the variables list.

Second, configure the AWS CLI by running `aws configure` with your AWS credentials and select profile for the desired account.
```
export AWS_PROFILE=<profile_name>
export AWS_REGION=<region_name>
```

Next, to begin the infrastructure provisioning process:

### install
```sh
# by default, setup.sh will try to find "setup.tfvars"
./setup.sh 
```

`./setup.sh` will first validate **setup.tfvars** for all variables and use default for the ones not found, it will then run `terraform init`, followed by `plan` and `apply` to provision infrastructure.

For step by step installation, you can use the following options:
```sh
# -i flag will run terraform init and verify backend infrastructure
./setup.sh -i
# -p flag will run terraform plan and create a tf plan
./setup.sh -p
# -a flag will run terraform apply and create the resources
./setup.sh -a
```

You can also run validation to check for errors before running `plan` and after running `apply` by using
the `-v` flag
```sh
./setup.sh -v
```

Alternatively, to uninstall all infrastructure:

```sh
./setup.sh -d
```

### Considerations for VPC setup

The the number of resources in the infrastructure will be created based on the VPC configuration. There are 2 scenarios:

- [Consumer Resources with Existing VPC](#consumer-svc-with-existing-vpc)
- [Consumer Resources with New VPC](#consumer-svc-with-new-vpc)

#### Consumer Resources with Existing VPC

For existing VPC and subnets, all we need are the resource ID of the VPC and the CIDRs of the private subnets. If using existing VPC it needs to have both private and public subnets as the resources will be created in private subnets. Also the private subnets should have outbound access to the internet. Therefore, we highly recommend reviewing your existing VPC to see if it fits or a new one should be created instead. Additionally, you can update the other variables like VPC name and consumer function name.

Example configuration for an existing VPC:
```yaml
aws_region="us-west-2"
tf_backend_bucket="sd-aws-consumer-tf-backend-11111111"
sd_broker_endpointsvc_map={"b1":[endpoint1,vpcinterface1],"b2":[endpoint2,vpcinterface2],"b3":[endpoint3,vpcinterface3]}
sd_broker_endpointsvc_port=9096
route53_zone_name=example.us-west-2.amazonaws.com
consumer_fn_name="screwdriver-consumer-svc"
vpc_id="vpc-1234"
private_subnets=["10.10.106.0/25", "10.10.106.128/25", "10.10.107.0/25", "10.10.107.128/25"]
sd_broker_secret_arn=arn:someexamplesecret
```
#### Consumer Resources with New VPC

In this case a VPC will be created and consumer service will be provisioned in the new VPC. The required configuration needed for a new VPC setup are the VPC CIDR, the list of private and public subnet CIDRs and the availability zones. The VPC CIDR prefix must be between `/16` and `/24`. Additionally, you can update the other variables like VPC name and consumer function name.

Example configuration for a new VPC:
```yaml
aws_region="us-west-2"
tf_backend_bucket="sd-aws-consumer-tf-backend-11111111"
sd_broker_endpointsvc_map={"b1":[endpoint1,vpcinterface1],"b2":[endpoint2,vpcinterface2],"b3":[endpoint3,vpcinterface3]}
sd_broker_endpointsvc_port=9096
route53_zone_name=example.us-west-2.amazonaws.com
consumer_fn_name="screwdriver-consumer-svc"
private_subnets=["10.10.106.0/25", "10.10.106.128/25", "10.10.107.0/25", "10.10.107.128/25"]
cidr_block="10.10.104.0/22"
public_subnets=["10.10.104.0/25", "10.10.104.128/25", "10.10.105.0/25", "10.10.105.128/25"]
azs=["us-west-2a", "us-west-2b", "us-west-2c", "us-west-2d"]
vpc_name="screwdriver-consumer"
sd_broker_secret_arn=arn:someexamplesecret
```
## Configurations

The config variables are all part of tfvar file. These variables will be used in creating the resources.


### Config Definitions

The following table describes all the configurable variables defined in `setup.tfvars`

| Name | Type | Description |
| - | - | - |
| aws_region <sup>*</sup> | String | AWS Region where resources will be provisioned |
| tf_backend_bucket <sup>*</sup> | String | Terraform backend S3 bucket for storing tf state |
| sd_broker_endpointsvc_map <sup>*</sup> | Map | Screwdriver Broker Service and VPC Endpoint Map |
| sd_broker_endpointsvc_port <sup>*</sup> | Integer | Screwdriver Broker Service Port |
| route53_zone_name <sup>*</sup> | String | Route 53 Private Zone name  |
| consumer_fn_name <sup>*</sup> | String | Screwdriver Consumer Service Name |
| vpc_id <sup>*</sup> | String | User VPC ID  |
| private_subnets <sup>*</sup> | List | List of private subnets |
| public_subnets <sup>#</sup> | List | List of public subnets |
| cidr_block <sup>#</sup> | String | CIDR block for the user VPC |
| vpc_name <sup>#</sup> | String | Name of the user VPC |
| azs <sup>#</sup> | List | List of availability zones |

<i><sup>*</sup> required config</i>

<i><sup>#</sup> required config when creating new VPC</i>

### Provider config vars
```aws_region="us-west-2"
tf_backend_bucket="sd-aws-consumer-tf-backend-<accountId>" #replace accountId
```
### Broker endpoint configuration will be provided by Screwdriver Team
```sd_broker_endpointsvc_map={"b1":[],"b2":[],"b3" : []}
sd_broker_endpointsvc_port=9096
route53_zone_name=null
consumer_fn_name="screwdriver-consumer-svc"
```
### User config for VPC (existing or new)
```
vpc_id=null
private_subnets=["10.10.106.0/25", "10.10.106.128/25", "10.10.107.0/25", "10.10.107.128/25"]
cidr_block="10.10.104.0/22"
public_subnets=["10.10.104.0/25", "10.10.104.128/25", "10.10.105.0/25", "10.10.105.128/25"]
azs=["us-west-2a", "us-west-2b", "us-west-2c", "us-west-2d"]
vpc_name="screwdriver-consumer"
```
