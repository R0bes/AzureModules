## Some Terraform modules for Azure

# Example Usage

To get access to the time series insight you have to provide your credentials. 
An example variables file is present in the base directory.
Also you have to run ```az login``` before terraform apply.

```
git clone https://www.github.com/R0bes/AzureModules.git
cd AzureModules
terraform init
az login
terrafomr apply -var-file="example.tfvars"
```

# Custom usage

## Device Twin

Create and destroy a device twin or edge device twin in an azure iot hub.
To use in your project:
* Clone this repository: 
  ```git clone https://www.github.com/R0bes/AzureModules.git Modules```
* Include in your terraform file:
  ```
  module "edge_device_twin" {
    source      = "./Modules/AzureDeviceTwin/"
    name        = <device_twin_name>
    iothub_name = <iot_hub.name>
    edge        = <boolean>
  }
  ```


## Time Series Insights

Create and destroy time series insigsts resources.
To use in your project:
* Clone this repository: 
  ```git clone https://www.github.com/R0bes/AzureModules.git Modules```
* Include in your terraform file:
  ```
  module "edge_device_twin" {
    source                  = "./Modules/AzureTimeSeriesInsights"
    name                    = <device_twin_name>
    edge                    = <boolean>
    location                = <location>
    resourcegroup_name      = <resource_group.name>
    storage_name            = <storage_account.name>
    storage_key             = <storage_account.primary_access_key>
    iothub_name             = <iot_hub.name>
    iothub_id               = <iot_hub.id>
    iothub_key              = <iot_hub.shared_access_policy[0].primary_key>
    principal_object_ids    = <principal_object_ids>
  }
  ```

* Where principal_object_ids look like:
  ```
  variable "principal_object_ids" {
    type    = list(object({ name=string, id=string }))
  }
  ```