param deploy bool = false
param location string
param functionAppName string
param functionStorageName string
param appInsightsConnectionString string
param adlsStorageName string
param eventHubAuthorizationRuleId string
param eventHubName string
param tags object = {}

resource hostStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = if (deploy) {
  name: functionStorageName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource adls 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: adlsStorageName
}

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = if (deploy) {
  name: 'plan-${functionAppName}'
  location: location
  kind: 'linux'
  tags: tags
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true
  }
}

resource app 'Microsoft.Web/sites@2024-04-01' = if (deploy) {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    reserved: true
    httpsOnly: true
    serverFarmId: plan.id
    siteConfig: {
      linuxFxVersion: 'Python|3.12'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'ENABLE_ORYX_BUILD'
          value: 'true'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorageName};AccountKey=${listKeys(resourceId('Microsoft.Storage/storageAccounts', functionStorageName), '2023-05-01').keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'ADLSConnection'
          value: 'DefaultEndpointsProtocol=https;AccountName=${adlsStorageName};AccountKey=${listKeys(adls.id, '2023-05-01').keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'EventHubConnection'
          value: listKeys(eventHubAuthorizationRuleId, '2024-01-01').primaryConnectionString
        }
        {
          name: 'EVENTHUB_NAME'
          value: eventHubName
        }
      ]
    }
  }
}

output functionAppName string = deploy ? functionAppName : ''
