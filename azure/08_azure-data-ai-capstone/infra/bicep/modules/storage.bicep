param location string
param storageName string
param fileSystemName string = 'datalake'
param developerPrincipalId string = ''
param tags object = {}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: true
    isHnsEnabled: true
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  name: 'default'
  parent: storage
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// In an HNS-enabled account, a blob container is exposed as an ADLS Gen2 filesystem.
resource fileSystem 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  name: fileSystemName
  parent: blobService
  properties: {
    publicAccess: 'None'
  }
}


var storageBlobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
resource developerStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(developerPrincipalId)) {
  scope: storage
  name: guid(storage.id, developerPrincipalId, storageBlobDataContributorRoleId)
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleId
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

output storageResourceId string = storage.id
output storageName string = storage.name
output dfsEndpoint string = storage.properties.primaryEndpoints.dfs
output fileSystemName string = fileSystem.name
