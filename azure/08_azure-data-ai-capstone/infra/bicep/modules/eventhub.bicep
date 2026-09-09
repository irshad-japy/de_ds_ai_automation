param location string
param namespaceName string
param eventHubName string
param skuName string = 'Standard'
param developerPrincipalId string = ''
param tags object = {}

resource ns 'Microsoft.EventHub/namespaces@2024-01-01' = {
  name: namespaceName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuName
    capacity: 1
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    minimumTlsVersion: '1.2'
  }
}

resource hub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  name: eventHubName
  parent: ns
  properties: {
    partitionCount: 2
    messageRetentionInDays: 1
    status: 'Active'
  }
}

resource functionListenerRule 'Microsoft.EventHub/namespaces/authorizationRules@2024-01-01' = {
  name: 'poc08-function-listener'
  parent: ns
  properties: {
    rights: [
      'Listen'
    ]
  }
}

// Local developer can send and receive with Entra ID when an object ID is supplied.
var eventHubOwnerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'f526a384-b230-433a-b45c-95f59c4a2dec')
resource developerEventHubRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(developerPrincipalId)) {
  scope: ns
  name: guid(ns.id, developerPrincipalId, eventHubOwnerRoleId)
  properties: {
    roleDefinitionId: eventHubOwnerRoleId
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

output namespaceName string = ns.name
output namespaceResourceId string = ns.id
output eventHubName string = hub.name
output functionListenerAuthorizationRuleId string = functionListenerRule.id
