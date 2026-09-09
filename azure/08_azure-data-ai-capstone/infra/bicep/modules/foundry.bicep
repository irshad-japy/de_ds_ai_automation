param location string
param accountName string
param projectName string
param deployModels bool = false
param chatDeploymentName string
param chatModelName string
param chatModelVersion string
param chatDeploymentSku string
param chatDeploymentCapacity int
param embeddingDeploymentName string
param embeddingModelName string
param embeddingModelVersion string
param embeddingDeploymentSku string
param embeddingDeploymentCapacity int
param developerPrincipalId string = ''
param tags object = {}

resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: accountName
  location: location
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  tags: tags
  properties: {
    allowProjectManagement: true
    customSubDomainName: accountName
    disableLocalAuth: false
    publicNetworkAccess: 'Enabled'
    restrictOutboundNetworkAccess: false
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  name: projectName
  parent: account
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: projectName
    description: 'POC-08 Azure Data + AI Capstone project'
  }
}

resource chatDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = if (deployModels) {
  name: chatDeploymentName
  parent: account

  // Azure AI Services can reject concurrent child writes on the same parent account.
  // Wait for the Foundry project operation to finish before creating the chat deployment.
  dependsOn: [
    project
  ]

  sku: {
    name: chatDeploymentSku
    capacity: chatDeploymentCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: chatModelName
      version: chatModelVersion
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
}

resource embeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = if (deployModels) {
  name: embeddingDeploymentName
  parent: account

  // Serialize model deployments because the Cognitive Services parent account
  // may reject simultaneous deployment writes.
  dependsOn: [
    chatDeployment
  ]

  sku: {
    name: embeddingDeploymentSku
    capacity: embeddingDeploymentCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: embeddingModelName
      version: embeddingModelVersion
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
}

var foundryUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '53ca6127-db72-4b80-b1b0-d745d6d5456d')
var openAiUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')

resource developerFoundryRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(developerPrincipalId)) {
  scope: project
  name: guid(project.id, developerPrincipalId, foundryUserRoleId)
  properties: {
    roleDefinitionId: foundryUserRoleId
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

resource developerOpenAiRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(developerPrincipalId)) {
  scope: account
  name: guid(account.id, developerPrincipalId, openAiUserRoleId)
  properties: {
    roleDefinitionId: openAiUserRoleId
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

output accountName string = account.name
output accountResourceId string = account.id
output projectName string = project.name
output projectResourceId string = project.id
