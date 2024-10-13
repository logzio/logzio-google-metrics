# Constants
telegraf_version="1.32.1"
telegraf_zip_name="telegraf.tar.gz"
default_telegraf_folder="./telegraf-${telegraf_version}/usr/bin/telegraf"
function_folder="./function_cloud"
function_name_hash=$RANDOM
function_name="metrics_gcp"

# Prints usage
# Output:
#   Help usage
function show_help () {
    echo -e "Usage: ./run.sh --listener_url=<listener_url> --token=<token> --gcp_region=<gcp_region> --function_name=<function_name> --telemetry_list=<telemetry_list>"
    echo -e " --listener_url=<listener_url>       Logz.io Listener URL (You can check it here https://docs.logz.io/user-guide/accounts/account-region.html)"
    echo -e " --token=<token>                     Logz.io token of the account you want to ship to."
    echo -e " --gcp_region=<gcp_region>           Region where you want to upload Cloud Funtion."
    echo -e " --function_name=<function_name>     Function name will be using as Cloud Function name and prefix for services."
    echo -e " --telemetry_list=<telemetry_list>   Will send metrics that match the Google metrics type. Array of strings splitted by comma. Detailed list you can find https://cloud.google.com/monitoring/api/metrics_gcp"
    echo -e " --help                              Show usage"
}

# Gets arguments
# Input:
#   Client's arguments ($@)
# Output:
#   listener_url - Logz.io Listener URL
#   token - Logz.io Token of the account user want to ship to.
#   telemetry_list - Metrics that match the Google metrics type. Array of strings splitted by comma..
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
            --telemetry_list=*)
                telemetry_list=$(echo "$1" | cut -d "=" -f2)
                if [[ "$telemetry_list" = "" ]]; then
                    echo -e "\033[0;31mrun.sh (1): No metrics types specified!\033[0;37m"
                    exit 1
                fi
                echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] telemetry_list = $telemetry_list" 
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
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to use GCloud CLI. Please install GCloud and login to proper account from where you want to send metrics..."
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
    if [[ -z "$telemetry_list" ]]; then
        is_error=true
        echo -e "\033[0;31mrun.sh (1): Metric type is missing please rerun the script with the relevant parameters\033[0;37m"
    fi
  
    if $is_error; then
        echo -e "\033[0;31mrun.sh (1): try './run.sh --help' for more information\033[0;37m"
        exit 1
    fi

    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Validation of arguments passed successfully."
}

# Download/UNZIP/Move Telegraf version as 1.27.4
# Error:
#   Exit Code 1
function download_Telegraf(){
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Downloading Telegraf from github ..."
    curl -fsSL https://dl.influxdata.com/telegraf/releases/telegraf-${telegraf_version}_linux_amd64.tar.gz > ./$telegraf_zip_name
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to download Telegraf..."
        exit 1
    fi

    # Unzip Telegraf file 
    tar -zxf ./$telegraf_zip_name --directory .
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to unzip Telegraf..."
        exit 1
    fi
    
    # Move Telegraf file to function folder
    mv $default_telegraf_folder $function_folder
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to move Telegraf to function's folder..."
        exit 1
    fi
    
    # Add permission to execute file for Telegraf
    chmod +x $function_folder/telegraf
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to give permission to Telegraf..."
        exit 1
    fi

    # Remove Telegraf zip tar.gz file
    rm -rf ./telegraf-${telegraf_version}
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to remove Telegraf folder  ..."
        exit 1
    fi
    
    # Remove telegraf zip tar.gz file
    rm -rf ./$telegraf_zip_name
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to remove Telegraf zip file  ..."
        exit 1
    fi

    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Downloaded Telegraf from github."
}


# Convert metrics_type string to array of strings
function build_string_metric_type(){
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Parsing metrics types..."

    if [[ ! -z "$telemetry_list" ]]; then
        filter=""
        array_filter_names=(${telemetry_list//,/ })

        last_element=${#array_filter_names[@]}
        current=0
        for name in "${array_filter_names[@]}"
        do
            current=$((current + 1))
            if [ $current -eq $last_element ]; then
                filter+="\"${name}/\","
            else
                filter+="\"${name}/\","
            fi
        done
        telemetry_list=$filter
    fi
    
	echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Parsed metrics types."
}


# Populate user's credentials to Telegraf configuration 
function populate_data(){
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Populating Telegraf config ..."

    tee function_cloud/telegraf.conf << END
[[inputs.stackdriver]]
  project = "${project_id}"
  metric_type_prefix_include = [
    ${telemetry_list}
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

    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Populated Telegraf config."
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

    if [[ "$function_name" =~ ^logzio_* ]];
    then
	    function_name_prefix="${function_name}"
    else
	    function_name_prefix="logzio_${function_name}"
    fi


    gcloud functions deploy $function_name_prefix  --gen2 --region=$gcp_region --entry-point=LogzioHandler --trigger-http --runtime=go121 --service-account=${account_name}@${project_id}.iam.gserviceaccount.com --source=./$function_folder  --no-allow-unauthenticated --set-env-vars=GOOGLE_APPLICATION_CREDENTIALS=./credentials.json
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to create Cloud Function."
        exit 1
    fi

    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Created GCP Cloud Function."
}

# Remove existing Cloud Function
function remove_cloud_function() {
    
    if [[ "$function_name" =~ ^logzio_* ]];
    then
	    function_name_prefix="${function_name}"
    else
	    function_name_prefix="logzio_${function_name}"
    fi

    if gcloud functions describe $function_name_prefix --region=$gcp_region &> /dev/null; then
        delete_code=$(gcloud functions delete $function_name_prefix --region=$gcp_region --quiet || true)
        if [[ $? -ne 0 ]]; then
            echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to remove Cloud Function."
        else 
            echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Cloud Function: $function_name_prefix removed."
        fi
    else
        echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Cloud Function: $function_name_prefix not found."
    fi
}


# Remove existing Service Account
function remove_service_account(){
    clean_function_name=${function_name//[^[:alnum:]]/}
    account_name="${clean_function_name:0:25}acc"
    is_service_account="$(gcloud iam service-accounts list --filter=$account_name@$project_id.iam.gserviceaccount.com --format="value(email)")"
    if [ ! -z "$is_service_account" ]
    then
        delete_code=$(gcloud iam service-accounts delete ${account_name}@${project_id}.iam.gserviceaccount.com --quiet || true)
        if [[ $? -ne 0 ]]; then
            echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to remove existing Service account: $account_name ."
        else
            echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Service account: $account_name removed."
        fi
    else
        echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Service account: $account_name not found."
    fi

}


# Create Service Account to run function
function create_service_account(){
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Create service account to run function ..."

    clean_function_name=${function_name//[^[:alnum:]]/}
    account_name="${clean_function_name:0:25}acc"
    
    cmd_create_service_account="gcloud iam service-accounts create ${account_name}"
    echo "$cmd_create_service_account"
    gcloud iam service-accounts create ${account_name}
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to create Service account: $account_name."
        exit 1
    else 
        echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Service account: $account_name created."    
    fi

    roles=("roles/cloudscheduler.serviceAgent" "roles/cloudfunctions.invoker" "roles/compute.viewer" "roles/monitoring.viewer" "roles/cloudasset.viewer" "roles/run.admin")

    for role in "${roles[@]}"; do
        gcloud projects add-iam-policy-binding ${project_id} --member serviceAccount:${account_name}@${project_id}.iam.gserviceaccount.com --role ${role}
        if [[ $? -ne 0 ]]; then
            echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to add ${role} to service account."
            exit 1
        fi
    done

    create_credentials_file
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Added permissions to service account."
}


# Copy credentials file
function create_credentials_file(){
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Create credentials-file."

    gcloud iam service-accounts keys create credentials.json --iam-account ${account_name}@${project_id}.iam.gserviceaccount.com
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to add permissions to service account."
        exit 1
    fi
    # Move Telegraf file to function folder
    mv ./credentials.json $function_folder
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to move Telegraf to function's folder..."
        exit 1
    fi
}



# Add Goolgle Job Scheduler for run function each minute
# Error:
#   Exit Code 1
function add_scheduler(){
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Add Job Scheduler for run Cloud Function ..."
    
    job_name="${function_name}_${function_name_hash}_job"

    is_job_scheduler="$(gcloud scheduler jobs list  --location=$gcp_region --filter=$job_name)"
    if [ ! -z "$is_job_scheduler" ]
    then
       gcloud scheduler jobs delete $job_name --location="$gcp_region"
    fi


    if [[ "$function_name" =~ ^logzio_* ]];
    then
	    function_name_prefix="${function_name}"
    else
	    function_name_prefix="logzio_${function_name}"
    fi

    gcloud scheduler jobs create http $job_name --location="$gcp_region" --schedule="*/5 * * * *" --uri="https://$gcp_region-$project_id.cloudfunctions.net/$function_name_prefix" --http-method=GET --oidc-service-account-email=${account_name}@${project_id}.iam.gserviceaccount.com
    if [[ $? -ne 0 ]]; then
        echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to create Job Scheduler."
        exit 1
    fi

    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Added Job Scheduler for run Cloud Function."

}


# Remove existing Job Scheduler
function remove_scheduler(){
    job_name="${function_name}_job"
    if gcloud scheduler jobs describe $job_name --location=$gcp_region &> /dev/null; then
        delete_code=$(gcloud scheduler jobs delete $job_name --location=$gcp_region --quiet || true)
        if [[ $? -ne 0 ]]; then
            echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to remove existing Job Scheduler: $job_name."
        else
            echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Job Scheduler: $job_name removed."
        fi
    else
        echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Job Scheduler: $job_name not found."
    fi
}
 

# Init script with proper message and display active user account
function gcloud_init_confs(){
    user_active_account="$(gcloud auth list --filter=status:ACTIVE --format="value(account)")"
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Your active account [${user_active_account}]"
}


# Choose and set project id
# Error:
#   Exit Code 1
function choose_and_set_project_id(){
    array_projects=()
    selected_projects=()
    count=0
    echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Choose and set project ids ..."
    # List all projects and store them in an array
    for project in $(gcloud projects list --format="value(projectId)")
    do
        count=$((count + 1))
        echo "[$count]:  $project"
        array_projects+=("$project")
    done
    # Add the option to deploy to all projects
    echo "[$((count + 1))]:  All Projects"

    # Prompt the user to select multiple projects
    read -p "Please fill in the project index numbers of the projects where you would like the integration to be deployed, separated by spaces (or type 'all' to select all projects): " -a mainmenuinput

    # Validate and store selected projects
if [[ "${mainmenuinput[0]}" == "all" || "${mainmenuinput[0]}" -eq $((count + 1)) ]]; then
        selected_projects=("${array_projects[@]}")
    else
        for input in "${mainmenuinput[@]}"
        do
            if [[ $input -ge 1 && $input -le $count ]]; then
                selected_projects+=("${array_projects[$((input-1))]}")
            else
                echo -e "\\n[WARNING] [$(date +"%Y-%m-%d %H:%M:%S")] Invalid selection: $input. Please enter values between 1 and $count, or type 'all'."
                choose_and_set_project_id
                return
            fi
        done
    fi
}


# Deploy resources to the selected projects
function deploy_resources_to_projects() {
    for project_id in "${selected_projects[@]}"
    do
        gcloud config set project $project_id
        if [[ $? -ne 0 ]]; then
            echo -e "[ERROR] [$(date +"%Y-%m-%d %H:%M:%S")] Failed to set project $project_id."
            exit 1
        fi
        echo -e "[INFO] [$(date +"%Y-%m-%d %H:%M:%S")] Setting up Logz.io integration resources in Project ID: '$project_id'..."
        
        # Call the functions to cleanup resources
        remove_cloud_function $project_id
        remove_scheduler $project_id
        remove_service_account $project_id

        # Call the functions to create resources
        create_service_account  $project_id
        enable_cloudfunction_api
        enable_monitoring_api        
        create_cloud_function $project_id
        add_scheduler $project_id
    done
}

# Initialize flow
is_gcloud_install
gcloud_init_confs
get_arguments "$@"
download_Telegraf
build_string_metric_type
populate_data
choose_and_set_project_id
deploy_resources_to_projects