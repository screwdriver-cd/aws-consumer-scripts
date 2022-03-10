#!/bin/bash
set -eo pipefail
CWD=$(dirname ${BASH_SOURCE})

declare TF_CMD
declare TF_VAR_FILE_NAME="./provision.tfvars.json"
declare TF_VAR_tf_backend_bucket
declare TF_VAR_tf_state_key="consumer.tfstate"
declare TF_VAR_tf_region
declare TF_VAR_tf_build_region
declare TF_PHASE_INTERFACES
declare TF_WORK_DIR='.'

function usage {
    echo "usage: $programname [-ipavro]"
    echo "  -i|--init     runs the init script"
    echo "  -p|--plan     runs the infra plan and produces an output file producer_infra.tfplan"
    echo "  -a|--apply    runs the apply script with the plan producer_infra.tfplan"
    echo "  -v|--validate runs the validate script"
    echo "  -r|--refresh  runs the refresh script"
    echo "  -o|--output   returns the output"
    echo "  -all|         runs all commands in sequence|for advanced usage"
    exit 1
}

check_dependencies() {
    declare -r deps=(terraform aws wget jq)
    declare -r install_docs=(
        'https://github.com/hashicorp/terraform/releases/latest'
        'https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html'
        'https://www.gnu.org/software/wget/'
        'https://github.com/stedolan/jq/releases/latest'
    )

    for ((i = 0, f = 0; i < ${#deps[@]}; i++)); do
        if ! command -v ${deps[$i]} &>/dev/null; then
            ((++f)) && echo "'${deps[$i]}' command is not found. Please refer to ${install_docs[$i]} for proper installation."
        fi
    done

    if [[ $f -ne 0 ]]; then
        exit 127
    fi
}

read_var_file() {
    data=`echo $1 | \
        jq '. | to_entries[]| select(.value | . == null or . == "") 
        | if .value == "" then .value |= "\\"\\(.)\\"" else . end | "\\(.key): \\(.value)"'`
    local dirtyfile=0
    if [ ! -z "$data" ];then
        echo "Will use empty key: $data"
        dirtyfile=0
    fi
}

check_svc_vars() {
    if  [ -e $TF_VAR_FILE_NAME ]; then 
        tfvarfile=$(cat $TF_VAR_FILE_NAME)
        read_var_file "$tfvarfile"
        dirtyfile=$0
        if [ "$dirtyfile" = true ];then
            echo "Please fix env.tfvars.json to proceed!!" 
            exit 1
        fi
        printf "===env varfile===\n"
        echo "${tfvarfile}"
        printf "===end varfile===\n"
    else
        echo "Please add file env.tfvars.json"
        exit 1
    fi
}

read_input() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -br|--buildregion)
                TF_PHASE_BUILDREGION="true"
                shift 1
                ;;
            -i|--init) 
                TF_CMD="init"
                shift 1
                ;;
            -d|--destroy)
                TF_CMD="destroy"
                shift 1
                ;;
            -p|--plan) 
                TF_CMD="plan" 
                shift 1
                ;;
            -a|--apply) 
                TF_CMD="apply" 
                shift 1
                ;;
            -r|--refresh) 
                TF_CMD="refresh" 
                shift 1
                ;;
            -v|--validate)
                TF_CMD="validate"
                shift 1 
                ;;
            -it|--interface)
                TF_CMD="refresh"
                TF_PHASE_INTERFACES="true"
                shift 1
                ;;
            -all)
                TF_CMD="all"
                shift 1 
                ;;
            -o|--output)
                TF_CMD="output"
                shift 1 
                ;;
            [?])
                usage
                exit 1
        esac
    done
}

declare TF_RESULT=0
run_tf_cmd() {
    tfvarfile=$1
    tfplanoutputfile=$2
    cd $TF_WORK_DIR/
    dir=`pwd`
    echo "Current workdir: $dir"
    echo "===Runnning terraform $TF_CMD script==="
    case "$TF_CMD" in
        "destroy") terraform destroy  -auto-approve -var-file=$tfvarfile ;;
        "validate") terraform validate ;;
        "init") terraform init -backend-config "bucket=$TF_VAR_tf_backend_bucket" -backend-config "key=$TF_VAR_tf_state_key" -backend-config "region=$TF_VAR_tf_region" ;;
        "plan") terraform plan -var-file=$tfvarfile -out $tfplanoutputfile ;;
        "refresh") terraform refresh -var-file=$tfvarfile ;;
        "apply") 
            terraform apply -auto-approve $tfplanoutputfile 
            TF_RESULT=$?        
        ;;
        "output") get_tf_output ;;
        *)
            terraform init -backend-config "bucket=$TF_VAR_tf_backend_bucket" -backend-config "key=$TF_VAR_tf_state_key" -backend-config "region=$TF_VAR_tf_region"
            terraform plan -var-file=$tfvarfile -out $tfplanoutputfile
            terraform apply -auto-approve $tfplanoutputfile
            TF_RESULT=$?
        ;;
    esac
    if [[ $TF_CMD == "apply" && $TF_RESULT == 0 ]];then
        echo "Nuking .terraform as apply step succeded"    
        rm -rf .terraform *.tfplan *.log .terraform.lock.hcl
    fi
}

get_tf_output() {
    output_var=$1
    res=`terraform output $output_var`
}

get_consumer_svc_pkg() {
    printf "===Getting screwdriver consumer-service package===\n"
    if [ ! -f "lambda/aws-consumer-service" ];then
        mkdir -p lambda
        cd lambda
        wget -q -O - https://github.com/screwdriver-cd/aws-consumer-service/releases/latest \
        | egrep -o '/screwdriver-cd/aws-consumer-service/releases/download/v[0-9.]*/aws-consumer-service_linux_amd64' \
        | wget --base=http://github.com/ -i - -O aws-consumer-service
        chmod +x ./aws-consumer-service
        cd ..
    fi
}

get_backend_info() {
    # get backend info
    TF_VAR_tf_backend_bucket=`jq -r '.tf_backend_bucket' $TF_VAR_FILE_NAME`
    TF_VAR_tf_region=`jq -r '.aws_region' $TF_VAR_FILE_NAME`
    TF_VAR_tf_build_region=`jq -r '.build_region' $TF_VAR_FILE_NAME`
}

retVal=0
check_bucket_exists() {
    bucket_name="$1"
    account="$2"
    retVal=0
    echo "Checking if backend bucket $bucket_name exists"
    set +e
    res=`aws s3api head-bucket --bucket $bucket_name 2>&1`
    set -e
    if [[ $res == *"An error occurred (404) when calling the HeadBucket operation: Not Found"* ]];then
        retVal=1
    fi
}
create_backend_bucket() {
    bucket_name="$1"
    region="$2"
    account="$3"
    
    check_bucket_exists $bucket_name $account

    if [ "$retVal" == 1 ];then
        echo "Creating backend bucket $bucket_name in region: $region"
        aws s3api create-bucket --bucket $bucket_name --create-bucket-configuration LocationConstraint=$region
        aws s3api put-public-access-block --bucket $bucket_name \
            --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
        #wait after creation 
        echo "Waiting for bucket $bucket_name in region: $region"
        aws s3api wait bucket-exists \
            --bucket "$bucket_name" \
            --expected-bucket-owner "$account" 
    fi
}

merge_default_values() {
    override_json=$1
    if  [ -e $override_json ];then
        default_file_name="./default.tfvars.json"
        jq -s '.[0] * .[1]' $default_file_name $override_json > provision.tfvars.json
    else
        echo "Please add file $override_json"
        exit 1
    fi
}


main() {
    
    check_dependencies

    read_input "$@"

    merge_default_values "setup.tfvars.json"

    check_svc_vars
    
    get_backend_info
  
    create_backend_bucket $TF_VAR_tf_backend_bucket $TF_VAR_tf_region $user_aws_account_id
  
    if [ "$TF_PHASE_BUILDREGION" == 'true' ];then
        TF_WORK_DIR="./build_region"
        echo "Creating resources for $TF_VAR_tf_build_region"
        TF_VAR_FILE_NAME="../provision.tfvars.json"
        TF_VAR_tf_state_key="consumerbuilds-$TF_VAR_tf_build_region.tfstate"  
        echo "Using Bucket:$TF_VAR_tf_backend_bucket,Region:$TF_VAR_tf_region,State:$TF_VAR_tf_state_key"
        run_tf_cmd "$TF_VAR_FILE_NAME" "builds-$TF_VAR_tf_build_region.tfplan"
    elif [ "$TF_PHASE_INTERFACES" == 'true' ];then
            TF_CMD="all"
            TF_WORK_DIR='./interface'
            echo "Creating interfaces"
            TF_VAR_FILE_NAME="./interface.tfvars.json"
            TF_VAR_tf_state_key="consumerinterface.tfstate"  
            echo "Using Bucket:$TF_VAR_tf_backend_bucket,Region:$TF_VAR_tf_region,State:$TF_VAR_tf_state_key"
            run_tf_cmd "$TF_VAR_FILE_NAME" "interfaces_infra.tfplan"
    else
        get_consumer_svc_pkg

        echo "Using Bucket:$TF_VAR_tf_backend_bucket,Region:$TF_VAR_tf_region,State:$TF_VAR_tf_state_key"

        run_tf_cmd "$TF_VAR_FILE_NAME" "consumer_infra.tfplan"

        get_tf_output
    fi

}

main "$@" 