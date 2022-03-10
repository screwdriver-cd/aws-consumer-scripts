# Screwdriver AWS Integration Consumer Service Scripts
Infrastructure-as-code script for onboarding to Screwdriver AWS Integration

## Introduction

This repository is meant to serve as an install/uninstall/update script to provision necessary cloud infrastructure resources required for Screwdriver AWS Integration. The following are the resources created by the installation script by default:
- 3 AWS VPC Endpoint Interface (1 for each availability zone)
- 1 AWS Route 53 Private Hosted Zone
- 3 AWS Route 53 Alias Records for each VPC Endpoint Interface
- 1 AWS Lambda as Screwdriver Consumer Service
- 1 AWS S3 Bucket as Screwdriver Consumer Build Bucket
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
- [jq](https://github.com/stedolan/jq/releases/latest)

All of these tools can be installed via Homebrew on Mac OS X.

## Configurations
The config variables are all part of `.tfvars` file. These variables will be used in creating the resources.

### Config Definitions


The following table describes all the configurable variables defined in `setup.tfvars.json`.

| Name | Type | Description |
| - | - | - |
| aws_region <sup>*</sup> | String | AWS Region where resources will be provisioned |
| user_aws_account_id <sup>*</sup> | String | The user AWS account ID |
| tf_backend_bucket <sup>*</sup> | String | Terraform backend S3 bucket for storing tf state |
| sd_broker_endpointsvc_map <sup>*</sup> | Map | Screwdriver Broker Service and VPC Endpoint Map |
| sd_broker_endpointsvc_port <sup>*</sup> | Integer | Screwdriver Broker Service Port |
| route53_zone_name <sup>*</sup> | String | Route 53 Private Zone name  |
| consumer_fn_name <sup>*</sup> | String | Screwdriver Consumer Service Name |
| consumer_bucket_name | String | Screwdriver Consumer Service Bucket Name |
| vpc_id <sup>*</sup> | String | User VPC ID  |
| private_subnets <sup>*</sup> | List | List of private subnets |
| public_subnets <sup>#</sup> | List | List of public subnets |
| cidr_block <sup>#</sup> | String | CIDR block for the user VPC |
| vpc_name <sup>#</sup> | String | Name of the user VPC |
| azs <sup>#</sup> | List | List of availability zones |
| kafka_topic <sup>*</sup> | String | Name of the kafka topic |
| kms_key_arn <sup>*</sup> | String | The Key ID of the KMS Key |
| build_region <sup>*</sup> | String | The region of the build vpc, can be same as or different from aws_region |
| build_vpc_id <sup>^</sup> | String | The VPC Id where builds will run of not creating new |
| create_build_vpc <sup>*</sup> | Boolean | Flag to create new vpc |
| build_cidr_block <sup>$^</sup> | String | CIDR block for build vpc |
| build_private_subnets <sup>$^</sup> | List | List of private subnets CIDR block for build VPC |
| build_public_subnets <sup>$^</sup> | List | List of public subnets CIDR block for build VPC |
| build_azs <sup>$^</sup> | List | List of availability zones for build vpc  |
| sd_broker_secret_arn <sup>*</sup> | String | The ARN of the AWS Secret for connecting to Screwdriver Endpoint |
| sd_build_kms_key_alias <sup>^</sup> | String | The KMS alias name for the builds encryption key |
| create_ecr <sup>^</sup> | Boolean | Flag to create AWS ECR |
| ecr_name <sup>$^</sup> | String | Name of the AWS ECR |
| consumer_role_arn <sup>$</sup> | String | IAM Build role for allowing permissions |
| create_service_role <sup>^</sup> | Boolean | Flag to create builds service role with codebuild permissions |
| build_role_name <sup>^</sup> | String | Name of the role for running builds |

The following table describes all the configurable variables defined in `interface.tfvars.json`.
This is part of the second phase of installation defined in Step 5 of [instructions](#begin-the-infrastructure-provisioning-process).

| Name | Type | Description |
| - | - | - |
| private_subnets  <sup>*</sup> | List | List of private subnets ids after output of first phase |
| security_group_id  <sup>*</sup> | String | The security group id created in the first phase|
| vpc_id <sup>*</sup> | String | User VPC ID after output of first phase |
| route53_zone_name | String | Route 53 Private Zone name  |
| aws_region <sup>*</sup> | String | AWS Region where resources will be provisioned |
| sd_broker_endpointsvc_map <sup>*</sup> | Map | Screwdriver Broker Service and VPC Endpoint Map |

<i><sup>*</sup> required config</i>
<i><sup>^</sup> Has default value </i>
<i><sup>#</sup> required config when creating new VPC</i>
<i><sup>$</sup> required config when create flag is set </i>

### Provider config vars (user created)
```
aws_region="us-west-2" # region where Screwdriver infra is provisioned
tf_backend_bucket="sd-aws-consumer-tf-backend-<accountId>" #replace accountId
build_region="us-east-1" # region where builds will run
```
### Broker config vars (from Screwdriver Admin)
```
sd_broker_endpointsvc_map={
    "us-west-2a": ["broker_1", "service_1"],
    "us-west-2b": ["broker_2", "service_2"]
}
sd_broker_endpointsvc_port=9096
route53_zone_name="kafka.us-west-2.amazonaws.com"
kafka_topic="builds-11111111-usw2"
kms_key_arn="arn:aws:kms:us-west-2:11111111:key/example-id"

```
### User config for Screwdriver Producer VPC (default)
```
private_subnets=["10.10.106.0/25", "10.10.106.128/25", "10.10.107.0/25", "10.10.107.128/25"]
cidr_block="10.10.104.0/22"
public_subnets=["10.10.104.0/25", "10.10.104.128/25", "10.10.105.0/25", "10.10.105.128/25"]
azs=["us-west-2a", "us-west-2b", "us-west-2c", "us-west-2d"]
vpc_name="screwdriver-consumer"
```
### User config for Build VPC (default)
```
create_build_vpc=true
build_private_subnets=["172.21.104.0/25", "172.21.104.128/25", "172.21.105.0/25"]
build_cidr_block="172.21.104.0/22"
build_public_subnets=[ "172.21.106.0/25", "172.21.106.128/25", "172.21.107.0/25"]
build_azs=["us-east-1a", "us-east-1b", "us-east-1c"]
build_vpc_name="screwdriver-build-consumer"
```
### Other default configs:
```
consumer_fn_name="screwdriver-consumer-service"
consumer_bucket_name="screwdriver-consumer-builds-11111111-usw2"
kms_key_alias": "screwdriver-integration-key",
sd_build_kms_key_alias": "screwdriver-builds-key"
ecr_name="screwdriver-hub"
```
### Create ECR (optionally):
```
create_ecr=true
consumer_role_arn:="arn:aws:iam::11111111:role/role-name"
```

## Prerequisite
To start using Screwdriver on your AWS account, please reach out to the Screwdriver Cluster Admins and get the values for broker endpoint configurations
- List of Screwdriver Broker Endpoint Service `sd_broker_endpointsvc_map` 
- Username and password for authenticating to the Broker Service

Manually in AWS Console or using `aws cli`
- Create a KMS Key.
- Create a secret in Amazon Secret Manager using the values and encrypt using KMS key.
- Optionally, you can also setup rotation for Secrets
- Create a backend bucket `tf_backend_bucket` manually in AWS Console in region `aws_region`

## Instructions
Git clone this repository [aws-consumer-service](https://github.com/screwdriver-cd/aws-consumer-service).
To get started, we need to update the var file with the required details. Please refer to [`setup.tfvars.json.tmpl`](./setup.tfvars.json.tmpl) and [`default.tfvars.json`](./default.tfvars.json) for the variables list and configuration definition for information on each argument. Rename file to `setup.tfvars.json`. Following the naming convention as per the template is recommended. This file also serves as the override for all default values in [`default.tfvars.json`](./default.tfvars.json). If you wish to override vpc creation, role creation and other settings from default, based on your environment you can specify in the setup.tfvars.json file and the script will refer to the new values.

Second, configure the AWS CLI by running `aws configure` with your AWS credentials and select profile for the desired account.
```
export AWS_PROFILE=<profile_name>
export AWS_REGION=<region_name>
```

### Begin the infrastructure provisioning process:

Note: The setup relies on terraform for provisioning so the backend configuration and state file are important for recovering from error or pushing future updates. The state file ends with `.tfstate` and will be automatically synced to the backend S3 bucket. This process generates two state files `consumer.tfstate` and `consumerinterface.tfstate`. There are 2 parts:
 - The VPC and Service Creation
 - The Endpoint Interface creation which depends on the subnets created with VPC.
 - Region Specific resource creation for running builds in various regions
Don't delete the state files in between the process 

- Step 1: Update and verify all the information in `setup.tfvars.json` file. This is the key source of information.

- Step 2: Run init. -i flag will run terraform init and verify backend infrastructure 
```sh
./setup.sh -i
``` 
You can also run validation to check for errors before running `plan` and after running `apply` by using
the `-v` flag
```sh
./setup.sh -v
```

- Step 3: Run plan. -p flag will run terraform plan and create a tf plan
```sh
./setup.sh -p
```

- Step 4: Run apply. -a flag will run terraform apply and create the resources
```sh
./setup.sh -a
```

- Step 5: Rename file [`interface.tfvars.json.tmpl`](./interface/interface.tfvars.json.tmpl) to `interface.tfvars.json`. The previous step produces the output for `vpc_id`, `security_group_id`, `private_subnets`, `route53_zone_name`. Using this information and information from `Step 1`, update the tfvars file.

- Step 6: The service is already created and we need to provision the interface to connect to Screwdriver Endpoint. Run the following. 
```sh
./setup.sh -it
```
-it flag will create the [interfaces](./interfaces)

Alternatively, to uninstall all infrastructure:

```sh
./setup.sh -d
```

- Step 7: Go to the AWS Lambda Console and verify the service connection in `consumer-service-lambda`. The trigger should be updated and the result from trigger should be `OK`

- Step 8: To run builds in various regions, update the `build_region` and `build_vpc_id` in the setup.tfvars.json file based on the region and run the following commands for each region.
```sh
./setup.sh -br -i

./setup.sh -br -p

./setup.sh -br -a
```  

- Step 9: Saving current `.tfvars` file info.
It is recommended that you keep your updated `.tfvars` file backup before cleaning up the repository.
Here are a few helpful commands to upload the `.tfvars` to your `tf_backend_bucket`
```sh
aws s3api put-object --bucket $tf_backend_bucket --key setup.tfvars.json --body setup.tfvars.json
aws s3api put-object --bucket $tf_backend_bucket --key interface.tfvars.json --body interface/interface.tfvars.json
```

- Step 9: Remove directory `aws-consumer-service`

### Considerations for VPC setup

The resources in the infrastructure will be created based on the VPC configuration. There are 2 scenarios:

- [Consumer Resources with Existing VPC](#consumer-svc-with-existing-vpc)
- [Consumer Resources with New VPC](#consumer-svc-with-new-vpc)

#### Consumer Resources with Existing VPC

For existing VPC and subnets, all we need are the resource ID of the VPC, the CIDRs of the private subnets and the Availability Zones. If using existing VPC it needs to have both private and public subnets as the resources will be created in private subnets. Also the private subnets should have outbound access to the internet. Therefore, we highly recommend reviewing your existing VPC to see if it fits or a new one should be created instead. The private subnets must be tagged with `Network:Private` tags to get the private subnets in this configuration. The Availability Zones are by default takes and `region-a|b|c` for new vpc creation. Additionally, you can update the other variables like VPC name and consumer function name.

Example mandatory configuration for an existing VPC:
```yaml
aws_region="us-west-2"
tf_backend_bucket="sd-aws-consumer-tf-backend-11111111"
vpc_id="vpc-1234"
azs=["us-west-2a", "us-west-2b", "us-west-2c"]
```
#### Consumer Resources with New VPC

In this case a VPC will be created and consumer service will be provisioned in the new VPC. The required configuration needed for a new VPC setup are the VPC CIDR, the list of private and public subnet CIDRs and the availability zones. The VPC CIDR prefix must be between `/16` and `/24`. Additionally, you can update the other variables like VPC name and consumer function name.

Example configuration for a new VPC:
```yaml
aws_region="us-west-2"
tf_backend_bucket="sd-aws-consumer-tf-backend-11111111"
#default values
private_subnets=["10.10.106.0/25", "10.10.106.128/25", "10.10.107.0/25", "10.10.107.128/25"]
cidr_block="10.10.104.0/22"
public_subnets=["10.10.104.0/25", "10.10.104.128/25", "10.10.105.0/25", "10.10.105.128/25"]
azs=["us-west-2a", "us-west-2b", "us-west-2c"]
```


# Frequently asked questions

1. Can I run builds in any region?
A: Yes, Screwdriver Consumer Infrastructure will provisioned based on the argument `aws_region` provided by Screwdriver Admins. Builds can run in any region specified in `build_regions`. You can rerun the setup for multiple regions by updating this value.
Note: Do not change the `aws_region` value and re-run the infrastructure.

2. How can I create a Build vpc?
A: Build VPC can be created by simply setting flag `create_build_vpc: true` in `setup.tfvars.json` file. The VPC, KMS key `sd_build_kms_key_alias` and build bucket `consumer_bucket_name` will be provisioned in the region specified in `build_regions`

3. How can I create an AWS ECR and use custom images?
A: Yes can set `create_ecr: true` to create a custom Elastic Container Registry `ecr_name` in your `build_regions`. The setup will add the required permissions. You will need to specify the build role that will have access to the ECR.

4. What are the docker images and environments that are supported for Code Build executor?
A: Screwdriver integration supports all docker images and environments that are supported by [AWS CodeBuild](https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html). You can specify the image in you screwdriver.yaml configuration.

5. I encountered and error in running setup, and some resources already exist, can I run delete infrastructure.
A: Delete should be used cautiously and are for advanced users. If you face any error, reach out to you cluster admins to resolve them. In most cases, existing resources can be imported to the current setup, without deleting.

6. How to use existing an VPC for consumer resources and build resources?
A: to use existing vpc's update setup.tfvars.json file with the vpc_id and build_vpc_id for the specific region and tag your private subnets with the following tag: {Network: Private}
