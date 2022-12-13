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

3. Set the `project id` for the project that you want to send logs from:

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
./run.sh --listener_url=<listener_url> --token=<token> --region=<region> --function_name=<function_name> --metric_types=<metric_types>
```

Replace the variables as per the table below:

| Parameter    | Description                                                                                                                                                   |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| listener_url | Use the listener URL specific to the region of your Logz.io account. You can look it up [here](https://docs.logz.io/user-guide/accounts/account-region.html). |
| token        | The metrics' shipping token of the account you want to ship to.                                                                                               |
| region       | Region where you want to upload Cloud Function. \*`Requires for Deploy to Cloud option for platform`.                                                         |

| function_name | Function name will be using as Google Cloud Function name. (Default:`metrics_gcp`) |
| metric_types | Will send metrics that match the Google metric type. Detailed list you can find [here](https://cloud.google.com/monitoring/api/metrics_gcp) (ex: `cloudfunctions.googleapis.com`) |

## Check Logz.io for your metrics

Give your metrics a few minutes to get from your system to ours, and then open [Kibana](https://app.logz.io/#/dashboard/metrics).

## License

Licensed under the [Apache 2.0](http://apache.org/licenses/LICENSE-2.0.txt) License.

## Update log

**1.0.0**

-   Initial Release
