param deploy bool = false
param location string
param workspaceName string
param managedResourceGroupName string
param storageName string
param fileSystemName string
param administratorLogin string
@secure()
param administratorPassword string
param tags object = {}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageName
}

resource workspace 'Microsoft.Synapse/workspaces@2021-06-01' = if (deploy) {
  name: workspaceName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    defaultDataLakeStorage: {
      accountUrl: 'https://${storageName}.dfs.${environment().suffixes.storage}'
      filesystem: fileSystemName
    }
    managedResourceGroupName: managedResourceGroupName
    sqlAdministratorLogin: administratorLogin
    sqlAdministratorLoginPassword: administratorPassword
    publicNetworkAccess: 'Enabled'
  }
}

var storageBlobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
resource synapseStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deploy) {
  scope: storage
  name: guid(storage.id, resourceId('Microsoft.Synapse/workspaces', workspaceName), storageBlobDataContributorRoleId)
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleId
    principalId: workspace!.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output workspaceName string = deploy ? workspaceName : ''
