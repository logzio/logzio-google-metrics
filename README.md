# GCP metrics to Logz.io

Collect Google Cloud Platform (GCP) Metrics from your cloud services.

## Resources

-   Monitoring API
-   Cloud Function

## Prerequisites

-   Installed [gcloud CLI](https://cloud.google.com/sdk/docs/install)
-   Active GCP account
-   Installed [jq](https://stedolan.github.io/jq/download/)

Make sure you are connected to the relevant GCP project

<details>1. Log in to your GCP account:

```shell
gcloud auth login
```

2. Navigate to the relevant project.

3. Set the `project id` for the project that you want to collect metrics from:

```shell
gcloud config set project <PROJECT_ID>
```

Replace `<PROJECT_ID>` with the relevant project Id.</details>

## Usage

1. Donwload and unzip the latest release of `logzio-google-metrics`.

2. Allow the `sh` file to execute code.

```shell
chmod +x run.sh
```

3. Run the code:

```
./run.sh --listener_url=<listener_url> --token=<token> --gcp_region=<gcp_region> --function_name=<function_name> --telemetry_list=<telemetry_list>
```

<b>When you run this script, you should choose the project ID/s where you need to run the integration, you can choose `all` to deploy resources on all projects</b>

Replace the variables as per the table below:

| Parameter            | Description                                                                                                                                                                                                         |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| listener_url         | Use the listener URL specific to the region of your Logz.io account. You can look it up [here](https://docs.logz.io/user-guide/accounts/account-region.html).                                                       |
| token                | The metrics' shipping token of the account you want to ship to.                                                                                                                                                     |
| gcp_region           | Google Cloud Region where you want to upload Cloud Function. \*`Requires for Deploy to Cloud option for platform`. To check available regions you can see [here](https://cloud.google.com/functions/docs/locations) |
| function_name_prefix | Function name will be using as Google Cloud Function name. (Default:`metrics_gcp`)                                                                                                                                  |
| telemetry_list       | Will send metrics that match the Google metric type. Detailed list you can find [here](https://cloud.google.com/monitoring/api/metrics_gcp) (ex: `cloudfunctions.googleapis.com`)                                   |

## Check Logz.io for your metrics

Give your metrics a few minutes to get from your system to ours, and then open [Metrics](https://app.logz.io/#/dashboard/metrics).

# Uninstall

###  gcp_region - Region where user want to remove Logz.io integration resources.
###  function_name - Name of the Cloud Function. Default is 'logzioHandler'

To uninstall the resources, run the following command:

```shell
chmod +x uninstall.sh && ./uninstall.sh --gcp_region=<region> --function_name=<function_name>
```

## License

Licensed under the [Apache 2.0](http://apache.org/licenses/LICENSE-2.0.txt) License.

## Changelog
- **1.2.0**:
  - Upgrade Telegraf to `1.32.1`.
  - Upgrade GoLang runtime to v1.21
  - Allow fresh deployment to multiple projects, includes 'all' option.
  - Add `uninstall.sh` option to remove resources.
  - **Breaking change**
    - Upgrade Google Cloud function to v2
      - Add additional required permissions for the function
  - Add function resources cleanup
  - Additional function debugging logs  
- **1.1.0**:
  - Upgrade Telegraf to `1.27.4`.
- **1.0.3**:
    - **Bug fix** for project id's with more than 2 digits.
- **1.0.1**:
    - Add function that user can choose project id where need to run integration, Rename params from metric_types to telemetry_list
- **1.0.0**:
    - Initial Release
