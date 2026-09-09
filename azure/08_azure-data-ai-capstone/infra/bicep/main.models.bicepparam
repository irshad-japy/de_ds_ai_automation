using './main.bicep'

// AI MODEL PROFILE: core resources + Foundry chat/embedding deployments.
// Verify model/version/SKU availability in your selected region before using this profile.
param location = readEnvironmentVariable('POC08_LOCATION', 'eastus')
param resourceGroupName = readEnvironmentVariable('POC08_RESOURCE_GROUP', 'rg-poc08-capstone')
param projectName = readEnvironmentVariable('POC08_PROJECT_NAME', 'poc08capstone')
param developerPrincipalId = readEnvironmentVariable('POC08_DEVELOPER_OBJECT_ID', '')

param searchSku = readEnvironmentVariable('POC08_SEARCH_SKU', 'free')
param documentIntelligenceSku = readEnvironmentVariable('POC08_DOCUMENT_SKU', 'F0')

param deployDatabricks = false
param deployAzureSql = false
param deployFunctionApp = false
param deployMachineLearning = false
param deploySynapse = false
param deployFoundryModels = true

param chatDeploymentName = readEnvironmentVariable('POC08_CHAT_DEPLOYMENT', 'gpt-5-mini')
param chatModelName = readEnvironmentVariable('POC08_CHAT_MODEL', 'gpt-5-mini')
param chatModelVersion = readEnvironmentVariable('POC08_CHAT_MODEL_VERSION', '2025-08-07')
param chatDeploymentSku = readEnvironmentVariable('POC08_CHAT_SKU', 'GlobalStandard')
param embeddingDeploymentName = readEnvironmentVariable('POC08_EMBEDDING_DEPLOYMENT', 'text-embedding-3-small')
param embeddingModelName = readEnvironmentVariable('POC08_EMBEDDING_MODEL', 'text-embedding-3-small')
param embeddingModelVersion = readEnvironmentVariable('POC08_EMBEDDING_MODEL_VERSION', '1')
param embeddingDeploymentSku = readEnvironmentVariable('POC08_EMBEDDING_SKU', 'Standard')
