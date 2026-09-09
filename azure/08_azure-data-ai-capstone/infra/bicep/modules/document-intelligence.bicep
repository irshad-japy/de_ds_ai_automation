param location string
param accountName string
param skuName string = 'F0'
param tags object = {}

resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: accountName
  location: location
  kind: 'FormRecognizer'
  sku: {
    name: skuName
  }
  tags: tags
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
}

output accountName string = account.name
output accountResourceId string = account.id
