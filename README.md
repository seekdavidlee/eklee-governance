# Introduction
This repo contains the management scripts for management of Resource Groups, role assignments for DevOps services and shared resources for the Eklee platform. Follow the steps below to setup your subscription.

1. Create a [service principal](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal) for use in your Azure tenant for the purpose of performing deployment work to your subscription. Take note of the client Id as the Principal Id to be used later.
2. Next login to CloudShell, clone this repository.
3. Lastly, run the following script which should create the necessary resource groups, resources and role assignments. 

You may have 2 subscriptions for dev or prod or a single subscription where both dev and prod resides. Regardless, pass in the correct BUILD_ENV which represents the environment.

```
./DeployBlueprint.ps1 -BUILD_ENV <dev or prod> -PRINCIPAL_ID <Principal Id> -PREFIX <Prefix for name of resources>
```