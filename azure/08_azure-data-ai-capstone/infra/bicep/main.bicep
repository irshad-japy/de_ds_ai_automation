targetScope = 'subscription'

@description('Azure region used by the POC resources. Choose a region that supports the AI models you plan to deploy.')
param location string = 'eastus'

@description('Resource group that contains the complete POC-08 lab.')
param resourceGroupName string = 'rg-poc08-capstone'

@minLength(3)
@maxLength(24)
@description('Short project name used in Azure resource names. Letters, numbers, and hyphens are safest.')
param projectName string = 'poc08capstone'

@description('Tags applied to the resource group and resources.')
param tags object = {
  project: 'POC-08'
  workload: 'azure-data-ai-capstone'
  environment: 'lab'
  managedBy: 'bicep'
}

// Core POC resources. These are enabled in the beginner profile.
param searchSku string = 'free'
param documentIntelligenceSku string = 'F0'
param eventHubSku string = 'Standard'

// Cost-controlled optional components.
param deployDatabricks bool = false
param databricksSku string = 'standard'
param deployAzureSql bool = false
param deployFunctionApp bool = false
param deployMachineLearning bool = false
param deploySynapse bool = false

// Model deployments are intentionally opt-in because model availability, version and quota are region/subscription specific.
param deployFoundryModels bool = false
param chatDeploymentName string = 'gpt-5-mini'
param chatModelName string = 'gpt-5-mini'
param chatModelVersion string = '2025-08-07'
param chatDeploymentSku string = 'GlobalStandard'
param chatDeploymentCapacity int = 10
param embeddingDeploymentName string = 'text-embedding-3-small'
param embeddingModelName string = 'text-embedding-3-small'
param embeddingModelVersion string = '1'
param embeddingDeploymentSku string = 'Standard'
param embeddingDeploymentCapacity int = 10

// Only required when Azure SQL/Synapse are enabled.
param sqlAdministratorLogin string = 'pocadmin'
@secure()
param sqlAdministratorPassword string = ''
param sqlDatabaseName string = 'poc08db'
param sqlDatabaseSku string = 'Basic'

// Optional local client firewall rule for Azure SQL. Leave blank to skip it.
param clientIpAddress string = ''

// Optional principal for local developer RBAC (usually the signed-in Azure user object ID).
param developerPrincipalId string = ''

var normalizedProject = toLower(replace(replace(projectName, '-', ''), '_', ''))
var suffix = take(uniqueString(subscription().id, resourceGroupName, projectName), 6)
var storageName = take('${normalizedProject}${suffix}', 24)
var logAnalyticsName = take('log-${projectName}-${suffix}', 63)
var appInsightsName = take('appi-${projectName}-${suffix}', 260)
var keyVaultName = take('kv-${projectName}-${suffix}', 24)
var eventHubNamespaceName = take('evhns-${projectName}-${suffix}', 50)
var dataFactoryName = take('adf-${projectName}-${suffix}', 63)
var searchServiceName = take('srch-${projectName}-${suffix}', 60)
var documentIntelligenceName = take('docai-${projectName}-${suffix}', 64)
var foundryAccountName = take('ai-${projectName}-${suffix}', 64)
var foundryProjectName = take('${projectName}-project', 64)
var databricksWorkspaceName = take('dbw-${projectName}-${suffix}', 64)
var sqlServerName = take('sql-${projectName}-${suffix}', 63)
var functionAppName = take('func-${projectName}-${suffix}', 60)
var functionStorageName = take('${normalizedProject}fn${suffix}', 24)
var mlWorkspaceName = take('mlw-${projectName}-${suffix}', 33)
var synapseWorkspaceName = take('syn-${projectName}-${suffix}', 50)

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module monitoring './modules/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    logAnalyticsName: logAnalyticsName
    appInsightsName: appInsightsName
    tags: tags
  }
}

module storage './modules/storage.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    location: location
    storageName: storageName
    fileSystemName: 'datalake'
    developerPrincipalId: developerPrincipalId
    tags: tags
  }
}

module keyVault './modules/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    location: location
    keyVaultName: keyVaultName
    tags: tags
  }
}

module events './modules/eventhub.bicep' = {
  name: 'eventhub'
  scope: rg
  params: {
    location: location
    namespaceName: eventHubNamespaceName
    eventHubName: 'shipment-events'
    skuName: eventHubSku
    tags: tags
    developerPrincipalId: developerPrincipalId
  }
}

module dataFactory './modules/datafactory.bicep' = {
  name: 'datafactory'
  scope: rg
  params: {
    location: location
    factoryName: dataFactoryName
    storageName: storageName
    fileSystemName: 'datalake'
    tags: tags
  }
  dependsOn: [storage]
}

module search './modules/search.bicep' = {
  name: 'search'
  scope: rg
  params: {
    location: location
    searchServiceName: searchServiceName
    skuName: searchSku
    tags: tags
    developerPrincipalId: developerPrincipalId
  }
}

module documentIntelligence './modules/document-intelligence.bicep' = {
  name: 'document-intelligence'
  scope: rg
  params: {
    location: location
    accountName: documentIntelligenceName
    skuName: documentIntelligenceSku
    tags: tags
  }
}

module foundry './modules/foundry.bicep' = {
  name: 'foundry'
  scope: rg
  params: {
    location: location
    accountName: foundryAccountName
    projectName: foundryProjectName
    deployModels: deployFoundryModels
    chatDeploymentName: chatDeploymentName
    chatModelName: chatModelName
    chatModelVersion: chatModelVersion
    chatDeploymentSku: chatDeploymentSku
    chatDeploymentCapacity: chatDeploymentCapacity
    embeddingDeploymentName: embeddingDeploymentName
    embeddingModelName: embeddingModelName
    embeddingModelVersion: embeddingModelVersion
    embeddingDeploymentSku: embeddingDeploymentSku
    embeddingDeploymentCapacity: embeddingDeploymentCapacity
    developerPrincipalId: developerPrincipalId
    tags: tags
  }
}

module databricks './modules/databricks.bicep' = {
  name: 'databricks'
  scope: rg
  params: {
    deploy: deployDatabricks
    location: location
    workspaceName: databricksWorkspaceName
    managedResourceGroupName: 'rg-managed-${databricksWorkspaceName}'
    skuName: databricksSku
    tags: tags
  }
}

module sql './modules/sql.bicep' = {
  name: 'sql'
  scope: rg
  params: {
    deploy: deployAzureSql
    location: location
    serverName: sqlServerName
    databaseName: sqlDatabaseName
    databaseSku: sqlDatabaseSku
    administratorLogin: sqlAdministratorLogin
    administratorPassword: sqlAdministratorPassword
    clientIpAddress: clientIpAddress
    tags: tags
  }
}

module functionApp './modules/functionapp.bicep' = {
  name: 'function-app'
  scope: rg
  params: {
    deploy: deployFunctionApp
    location: location
    functionAppName: functionAppName
    functionStorageName: functionStorageName
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    adlsStorageName: storageName
    eventHubAuthorizationRuleId: events.outputs.functionListenerAuthorizationRuleId
    eventHubName: 'shipment-events'
    tags: tags
  }
  dependsOn: [storage, events, monitoring]
}

module machineLearning './modules/machine-learning.bicep' = {
  name: 'machine-learning'
  scope: rg
  params: {
    deploy: deployMachineLearning
    location: location
    workspaceName: mlWorkspaceName
    storageResourceId: storage.outputs.storageResourceId
    keyVaultResourceId: keyVault.outputs.keyVaultResourceId
    appInsightsResourceId: monitoring.outputs.appInsightsResourceId
    tags: tags
  }
}

module synapse './modules/synapse.bicep' = {
  name: 'synapse'
  scope: rg
  params: {
    deploy: deploySynapse
    location: location
    workspaceName: synapseWorkspaceName
    managedResourceGroupName: 'rg-managed-${synapseWorkspaceName}'
    storageName: storageName
    fileSystemName: 'datalake'
    administratorLogin: sqlAdministratorLogin
    administratorPassword: sqlAdministratorPassword
    tags: tags
  }
  dependsOn: [storage]
}

output resourceGroupName string = resourceGroupName
output location string = location
output storageAccountName string = storageName
output adlsAccountUrl string = 'https://${storageName}.dfs.${environment().suffixes.storage}'
output adlsFileSystem string = 'datalake'
output eventHubNamespaceName string = eventHubNamespaceName
// Event Hubs uses the Service Bus DNS namespace in Azure public cloud.
// environment().suffixes doesn't expose a serviceBus field, so keep this explicit for this POC.
output eventHubFullyQualifiedNamespace string = '${eventHubNamespaceName}.servicebus.windows.net'
output eventHubName string = 'shipment-events'
output dataFactoryName string = dataFactoryName
output dataFactoryPipelineName string = dataFactory.outputs.pipelineName
output searchServiceName string = searchServiceName
output searchEndpoint string = 'https://${searchServiceName}.search.windows.net'
output documentIntelligenceName string = documentIntelligenceName
output documentIntelligenceEndpoint string = 'https://${documentIntelligenceName}.cognitiveservices.azure.com/'
output foundryAccountName string = foundryAccountName
output foundryProjectName string = foundryProjectName
output foundryProjectEndpoint string = 'https://${foundryAccountName}.services.ai.azure.com/api/projects/${foundryProjectName}'
output azureOpenAIEndpoint string = 'https://${foundryAccountName}.openai.azure.com'
output chatDeploymentName string = chatDeploymentName
output embeddingDeploymentName string = embeddingDeploymentName
output keyVaultName string = keyVaultName
output logAnalyticsName string = logAnalyticsName
output applicationInsightsName string = appInsightsName
output databricksWorkspaceName string = deployDatabricks ? databricksWorkspaceName : ''
output sqlServerName string = deployAzureSql ? sqlServerName : ''
output sqlDatabaseName string = deployAzureSql ? sqlDatabaseName : ''
output sqlAdministratorLogin string = deployAzureSql ? sqlAdministratorLogin : ''
output functionAppName string = deployFunctionApp ? functionAppName : ''
output machineLearningWorkspaceName string = deployMachineLearning ? mlWorkspaceName : ''
output synapseWorkspaceName string = deploySynapse ? synapseWorkspaceName : ''
