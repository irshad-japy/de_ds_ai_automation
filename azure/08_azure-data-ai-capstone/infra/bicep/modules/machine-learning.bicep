param deploy bool = false
param location string
param workspaceName string
param storageResourceId string
param keyVaultResourceId string
param appInsightsResourceId string
param tags object = {}

resource workspace 'Microsoft.MachineLearningServices/workspaces@2025-04-01' = if (deploy) {
  name: workspaceName
  location: location
  kind: 'Default'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: workspaceName
    description: 'Optional POC-08 workspace for POC-07 delay-risk model reuse.'
    storageAccount: storageResourceId
    keyVault: keyVaultResourceId
    applicationInsights: appInsightsResourceId
    publicNetworkAccess: 'Enabled'
  }
}

output workspaceName string = deploy ? workspaceName : ''
