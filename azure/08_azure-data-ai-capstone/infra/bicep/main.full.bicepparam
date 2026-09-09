using './main.bicep'

// FULL LAB PROFILE: creates optional Azure components in addition to the core resources.
// IMPORTANT: this can create billable resources. Delete the resource group when finished.
param location = readEnvironmentVariable('POC08_LOCATION', 'eastus')
param resourceGroupName = readEnvironmentVariable('POC08_RESOURCE_GROUP', 'rg-poc08-capstone')
param projectName = readEnvironmentVariable('POC08_PROJECT_NAME', 'poc08capstone')
param developerPrincipalId = readEnvironmentVariable('POC08_DEVELOPER_OBJECT_ID', '')

param searchSku = readEnvironmentVariable('POC08_SEARCH_SKU', 'free')
param documentIntelligenceSku = readEnvironmentVariable('POC08_DOCUMENT_SKU', 'F0')

param deployDatabricks = true
param deployAzureSql = true
param deployFunctionApp = true
param deployMachineLearning = true
param deploySynapse = true
param deployFoundryModels = false

param sqlAdministratorLogin = readEnvironmentVariable('POC08_SQL_ADMIN_LOGIN', 'pocadmin')
param sqlAdministratorPassword = readEnvironmentVariable('POC08_SQL_ADMIN_PASSWORD', '')
param clientIpAddress = readEnvironmentVariable('POC08_CLIENT_IP', '')
