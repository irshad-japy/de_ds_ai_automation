param deploy bool = false
param location string
param workspaceName string
param managedResourceGroupName string
param skuName string = 'standard'
param tags object = {}

resource workspace 'Microsoft.Databricks/workspaces@2024-05-01' = if (deploy) {
  name: workspaceName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    managedResourceGroupId: subscriptionResourceId('Microsoft.Resources/resourceGroups', managedResourceGroupName)
    parameters: {
      enableNoPublicIp: {
        value: false
      }
    }
  }
}

output workspaceName string = deploy ? workspaceName : ''
output workspaceResourceId string = deploy ? resourceId('Microsoft.Databricks/workspaces', workspaceName) : ''
