param deploy bool = false
param location string
param serverName string
param databaseName string
param databaseSku string = 'Basic'
param administratorLogin string
@secure()
param administratorPassword string
param clientIpAddress string = ''
param tags object = {}

resource server 'Microsoft.Sql/servers@2021-11-01' = if (deploy) {
  name: serverName
  location: location
  tags: tags
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource database 'Microsoft.Sql/servers/databases@2021-11-01' = if (deploy) {
  name: databaseName
  parent: server
  location: location
  sku: databaseSku == 'Basic' ? {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  } : {
    name: databaseSku
    tier: 'Standard'
    capacity: 10
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}

resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2021-11-01' = if (deploy) {
  name: 'AllowAzureServices'
  parent: server
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource localClient 'Microsoft.Sql/servers/firewallRules@2021-11-01' = if (deploy && !empty(clientIpAddress)) {
  name: 'LocalDeveloper'
  parent: server
  properties: {
    startIpAddress: clientIpAddress
    endIpAddress: clientIpAddress
  }
}

output serverName string = deploy ? serverName : ''
output databaseName string = deploy ? databaseName : ''
output serverFqdn string = deploy ? '${serverName}.database.windows.net' : ''
