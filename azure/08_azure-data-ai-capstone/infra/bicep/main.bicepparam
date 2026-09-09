using './main.bicep'

// BEGINNER PROFILE: deploy the core integration resources first.
// No subscription_id is stored here. Azure CLI uses the active subscription from `az account show`.
param location = readEnvironmentVariable('POC08_LOCATION', 'eastus')
param resourceGroupName = readEnvironmentVariable('POC08_RESOURCE_GROUP', 'rg-poc08-capstone')
param projectName = readEnvironmentVariable('POC08_PROJECT_NAME', 'poc08capstone')
param developerPrincipalId = readEnvironmentVariable('POC08_DEVELOPER_OBJECT_ID', '')

param searchSku = readEnvironmentVariable('POC08_SEARCH_SKU', 'free')
param documentIntelligenceSku = readEnvironmentVariable('POC08_DOCUMENT_SKU', 'F0')
param eventHubSku = 'Standard'

// Reuse POC-02/POC-07 resources at first. Turn these on only if you want fresh paid resources.
param deployDatabricks = false
param deployAzureSql = false
param deployFunctionApp = false
param deployMachineLearning = false
param deploySynapse = false

// Model deployment is a separate opt-in because model availability/quota is subscription + region dependent.
param deployFoundryModels = false
