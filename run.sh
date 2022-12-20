# Constants
telegraf_version="1.24.4"
telegraf_zip_name="telegraf.tar.gz"
default_telegraf_folder="./telegraf-${telegraf_version}/usr/bin/telegraf"
function_folder="./function_cloud"
function_name_hash=$RANDOM | md5sum | head -c 10
function_name="metrics_gcp"

# Prints usage
# Output:
#   Help usage
function show_help () {
    echo -e "Usage: ./run.sh --listener_url=<listener_url> --token=<token> --gcp_region=<gcp_region> --function_name=<function_name> --metric_types=<metric_types>"
    echo -e " --listener_url=<listener_url>       Logz.io Listener URL (You can check it here https://docs.logz.io/user-guide/accounts/account-region.html)"
    echo -e " --token=<token>                     Logz.io token of the account you want to ship to."
    echo -e " --gcp_region=<gcp_region>           Region where you want to upload Cloud Funtion."
    echo -e " --function_name=<function_name>     Function name will be using as Cloud Function name and prefix for services."
    echo -e " --metric_types=<metric_types>       Will send metrics that match the Google metrics type. Array of strings splitted by comma. Detailed list you can find https://cloud.google.com/monitoring/api/metrics_gcp"
    echo -e " --help                              Show usage"
}

# Gets arguments
# Input:
#   Client's arguments ($@)
# Output:
#   listener_url - Logz.io Listener URL
#   token - Logz.io Token of the account user want to ship to.
#   metric_type - Metrics that match the Google metrics type. Array of strings splitted by comma..
# Error:
#   Exit Code 1

function get_arguments () {
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Getting arguments ..."
    while true; do
        case "$1" in
            --help)
                show_help
                exit
                ;;
            --listener_url=*)
                listener_url=$(echo "$1" | cut -d "=" -f2)
                if [[ "$listener_url" = "" ]]; then
                    echo -e "\033[0;31mrun.sh (1): no Logz.io Listener URL specified!\033[0;37m"
                    exit 1
                fi
                echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] listener_url = $listener_url"
                ;;
            --token=*)
                token=$(echo "$1" | cut -d "=" -f2)
                if [[ "$token" = "" ]]; then
                    echo -e "\033[0;31mrun.sh (1): no Logz.io token specified!\033[0;37m"
                    exit 1
                fi
                echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] token = $token"
                ;;
            --metric_types=*)
                metric_types=$(echo "$1" | cut -d "=" -f2)
                if [[ "$metric_types" = "" ]]; then
                    echo -e "\033[0;31mrun.sh (1): No metrics types specified!\033[0;37m"
                    exit 1
                fi
                echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] metric_types = $metric_types" 
                ;;
            --gcp_region=*)
                gcp_region=$(echo "$1" | cut -d "=" -f2)
                if [[ "$gcp_region" = "" ]]; then
                    echo -e "\033[0;31mrun.sh (1): No Google Cloud Region specified!\033[0;37m"
                    exit 1
                fi
                echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] gcp_region = $gcp_region" 
                ;;
            --function_name=*)
                function_name=$(echo "$1" | cut -d "=" -f2)
                if [[ "$function_name" = "" ]]; then
                    echo -e "\033[0;31mrun.sh (1): No function name specified!\033[0;37m"
                    #Define default
					function_name="metrics_gcp"
                fi
                echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] function_name = $function_name" 
                ;;
            "")
                break
                ;;
            *)
                echo -e "\033[0;31m run.sh (1): unrecognized flag\033[0;37m"
                echo -e "\033[0;31ma run.sh (1): run.sh (1): try './run.sh --help' for more information\033[0;37m"
                exit 1
                ;;
        esac
        shift
    done
    check_validation
}


# Ping GCloud
# Output:
# Error:
#   Exit Code 1
function is_gcloud_install(){
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")]running command gcloud -v .."

    gcloud_ping=`gcloud -v 2>/dev/null | wc -w`

    if [ $gcloud_ping -gt 0 ]
    then
        return
    else
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to get gcloud CLI. Please install Gcloud and login to proper account from where you want to send metrics..."
        exit 1	
    fi
}


# Checks validation of the arguments
# Error:
#   Exit Code 1
function check_validation () {
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Checking validation ..."

    local is_error=false

    if [[ -z "$listener_url" ]]; then
        is_error=true
        echo -e "\033[0;31mrun.sh (1): Logz.io Listener URL is missing please rerun the script with the relevant parameters\033[0;37m"
    fi
    if [[ -z "$token" ]]; then
        is_error=true
        echo -e "\033[0;31mrun.sh (1): Logz.io Token is missing please rerun the script with the relevant parameters\033[0;37m"
    fi
    if [[ -z "$gcp_region" ]]; then
        is_error=true
        echo -e "\033[0;31mrun.sh (1): Region for Google Cloud Platform is missing please rerun the script with the relevant parameters\033[0;37m"
    fi
    if [[ -z "$metric_types" ]]; then
        is_error=true
        echo -e "\033[0;31mrun.sh (1): Metric type is missing please rerun the script with the relevant parameters\033[0;37m"
    fi
  
    if $is_error; then
        echo -e "\033[0;31mrun.sh (1): try './run.sh --help' for more information\033[0;37m"
        exit 1
    fi

    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Validation of arguments passed."
}

# Download/UNZIP/Move Telegraf version as 1.24.4
# Error:
#   Exit Code 1
function download_telegraf(){
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Downloading telegraf from github ..."
    curl -fsSL https://dl.influxdata.com/telegraf/releases/telegraf-${telegraf_version}_linux_amd64.tar.gz > ./$telegraf_zip_name
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to download telegraf..."
        exit 1
    fi

    # Unzip telegraf file 
    tar -zxf ./$telegraf_zip_name --directory .
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to unzip telegraf..."
        exit 1
    fi
    
    # Move telegraf file to function folder
    mv $default_telegraf_folder $function_folder
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to move telegraf to function folder..."
        exit 1
    fi
    
    # Add permission to execute file for telegraf
    chmod +x $function_folder/telegraf
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to give permission to telegraf..."
        exit 1
    fi

    # Remove telegraf zip tar.gz file
    rm -rf ./telegraf-${telegraf_version}
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to remove telegraf folder  ..."
        exit 1
    fi
    
    # Remove telegraf zip tar.gz file
    rm -rf ./$telegraf_zip_name
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to remove telegraf zip file  ..."
        exit 1
    fi

    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Downloaded telegraf from github."
}

# Convert metrics_type string to array of strings
function build_string_metric_type(){
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Parsing metrics types..."

    if [[ ! -z "$metric_types" ]]; then
        filter=""
        array_filter_names=(${metric_types//,/ })

        last_element=${#array_filter_names[@]}
        current=0
        for name in "${array_filter_names[@]}"
        do
            current=$((current + 1))
            if [ $current -eq $last_element ]; then
                filter+="\"${name}\""
            else
                filter+="\"${name}\","
            fi
        done
        metric_types=$filter
    fi
    
	echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Parsed metrics types."
}


# Populate user's credentials to telegraf configuration 
function populate_data(){
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Populating telegraf config ..."

    # Remove telegraf.conf for create clean
    rm -rf ./function_cloud/telegraf.conf
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Error to remove..."
    fi

    tee -a function_cloud/telegraf.conf << END
    [[inputs.stackdriver]]
      project = "${project_id}"
      metric_type_prefix_include = [
        ${metric_types}
      ]
      interval = "1m"

    [[outputs.http]]
      url = "https://${listener_url}:8053"
      data_format = "prometheusremotewrite"
      [outputs.http.headers]
        Content-Type = "application/x-protobuf"
        Content-Encoding = "snappy"
        X-Prometheus-Remote-Write-Version = "0.1.0"
        Authorization = "Bearer ${token}"
END

    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Populated telegraf config."
}


# Get project ID 
# Error:
#   Exit Code 1
function get_project_id(){
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Creating GCP cloud function..."

    gcloud config get-value project
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to get user project id  ..."
        exit 1
    else
        project_id="$(gcloud config get-value project)"
    fi

    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Created GCP cloud function."
}

# Enable GCP Cloud Function API
# Error:
#   Exit Code 1
function enable_cloudfunction_api(){
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Enabling Cloud Function API..."

    gcloud services enable cloudfunctions.googleapis.com
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to enable Cloud Function API."
        exit 1
    fi

    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Enabled Cloud Function API."
}

# Enable GCP Monitoring API
# Error:
#   Exit Code 1
function enable_monitoring_api(){
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Enabling Monitoring API..."

    gcloud services enable monitoring.googleapis.com
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to enable Monitoring API."
        exit 1
    fi

    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Enabled Monitoring API."
}



# Create Google Cloud Function
# Error:
#   Exit Code 1
function create_function(){
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Creating GCP Cloud Function..."

    function_name_sufix="${function_name}_func_logzio"

    gcloud functions deploy $function_name_sufix --region=$gcp_region --entry-point=LogzioHandler --trigger-http --runtime=go116 --service-account=${account_name}@${project_id}.iam.gserviceaccount.com --source=./function_cloud  --no-allow-unauthenticated
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to create Cloud Function."
        exit 1
    fi

    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] CreateD GCP Cloud Function."
}

# Error:
#   Exit Code 1
function delete_service_account_to_run_func(){
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Delete account to run function..."

    clean_function_name=${function_name//[^[:alnum:]]/}
    account_name="logzio${clean_function_name}account"

    gcloud iam service-accounts delete ${account_name}@${project_id}.iam.gserviceaccount.com
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to Create service account."
        exit 1
    fi

    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Added permission to run function."
}



# Error:
#   Exit Code 1
function create_service_account_to_run_func(){
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Add permission to run function ..."
    

    clean_function_name=${function_name//[^[:alnum:]]/}
	
    account_name="logzio${clean_function_name}account"
	is_service_account="$(gcloud iam service-accounts list --filter=$account_name@$project_id.iam.gserviceaccount.com --format="value(email)")"
	if [ ! -z "$is_service_account" ]
    then
      delete_service_account_to_run_func
    fi
	
    gcloud iam service-accounts create ${account_name}
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to Create service account."
        exit 1
    fi

    gcloud projects add-iam-policy-binding ${project_id} --member serviceAccount:${account_name}@${project_id}.iam.gserviceaccount.com --role roles/cloudfunctions.invoker
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to add permissions to service account."
        exit 1
    fi

    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Added permission to run function."
}


# Add Goolgle Job Scheduler for run function each minute
# Error:
#   Exit Code 1
function add_scheduler(){
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Add Job Scheduler for run Cloud Function ..."
    
    job_name="${function_name}_job"

    gcloud scheduler jobs create http $job_name --location="$gcp_region" --schedule="* * * * *" --uri="https://$gcp_region-$project_id.cloudfunctions.net/$function_name" --http-method=GET --oidc-service-account-email=${account_name}@${project_id}.iam.gserviceaccount.com
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to create Job Scheduler."
        exit 1
    fi

    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Added Job Scheduler for run Cloud Function."
}

# Initialize flow
is_gcloud_install
get_project_id

get_arguments "$@"
download_telegraf

build_string_metric_type
populate_data

create_service_account_to_run_func
enable_cloudfunction_api
enable_monitoring_api
create_function
add_scheduler