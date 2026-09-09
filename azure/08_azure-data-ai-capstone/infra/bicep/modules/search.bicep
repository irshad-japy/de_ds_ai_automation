param location string
param searchServiceName string
param skuName string = 'free'
param developerPrincipalId string = ''
param tags object = {}

resource search 'Microsoft.Search/searchServices@2025-05-01' = {
  name: searchServiceName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: skuName
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'Default'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
  }
}

var searchServiceContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7ca78c08-252a-4471-8644-bb5ff32d4ba0')
var searchIndexDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8ebe5a00-799e-43f5-93ac-243d3dce84a7')
var searchIndexDataReaderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1407120a-92aa-4202-b7e9-c0e197c71c8f')

resource developerSearchServiceRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(developerPrincipalId)) {
  scope: search
  name: guid(search.id, developerPrincipalId, searchServiceContributorRoleId)
  properties: {
    roleDefinitionId: searchServiceContributorRoleId
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

resource developerSearchDataContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(developerPrincipalId)) {
  scope: search
  name: guid(search.id, developerPrincipalId, searchIndexDataContributorRoleId)
  properties: {
    roleDefinitionId: searchIndexDataContributorRoleId
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

resource developerSearchDataReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(developerPrincipalId)) {
  scope: search
  name: guid(search.id, developerPrincipalId, searchIndexDataReaderRoleId)
  properties: {
    roleDefinitionId: searchIndexDataReaderRoleId
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

output searchServiceName string = search.name
output searchResourceId string = search.id
