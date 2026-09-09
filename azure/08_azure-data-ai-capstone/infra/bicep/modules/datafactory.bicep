param location string
param factoryName string
param storageName string
param fileSystemName string = 'datalake'
param tags object = {}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageName
}

resource factory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: factoryName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

var storageBlobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
resource adfStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(storage.id, factory.id, storageBlobDataContributorRoleId)
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleId
    principalId: factory.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource adlsLinkedService 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: 'ls_adls_gen2'
  parent: factory
  properties: {
    type: 'AzureBlobFS'
    typeProperties: {
      url: storage.properties.primaryEndpoints.dfs
      authenticationType: 'ManagedIdentity'
    }
  }
}

resource rawOrdersDataset 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: 'ds_raw_orders_csv'
  parent: factory
  properties: {
    linkedServiceName: {
      referenceName: adlsLinkedService.name
      type: 'LinkedServiceReference'
    }
    type: 'DelimitedText'
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileSystem: fileSystemName
        folderPath: 'raw/orders'
        fileName: 'orders_001.csv'
      }
      columnDelimiter: ','
      escapeChar: '\\'
      firstRowAsHeader: true
      quoteChar: '"'
    }
    schema: []
  }
}

resource bronzeOrdersDataset 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: 'ds_bronze_orders_csv'
  parent: factory
  properties: {
    linkedServiceName: {
      referenceName: adlsLinkedService.name
      type: 'LinkedServiceReference'
    }
    type: 'DelimitedText'
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileSystem: fileSystemName
        folderPath: 'bronze/orders'
        fileName: 'orders_001.csv'
      }
      columnDelimiter: ','
      escapeChar: '\\'
      firstRowAsHeader: true
      quoteChar: '"'
    }
    schema: []
  }
}

resource pipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'pl_orders_raw_to_bronze'
  parent: factory
  properties: {
    activities: [
      {
        name: 'CopyRawOrdersToBronze'
        type: 'Copy'
        typeProperties: {
          source: {
            type: 'DelimitedTextSource'
            storeSettings: {
              type: 'AzureBlobFSReadSettings'
              recursive: false
            }
          }
          sink: {
            type: 'DelimitedTextSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
              copyBehavior: 'PreserveHierarchy'
            }
            formatSettings: {
              type: 'DelimitedTextWriteSettings'
              quoteAllText: true
              fileExtension: '.csv'
            }
          }
        }
        inputs: [
          {
            referenceName: rawOrdersDataset.name
            type: 'DatasetReference'
          }
        ]
        outputs: [
          {
            referenceName: bronzeOrdersDataset.name
            type: 'DatasetReference'
          }
        ]
        policy: {
          timeout: '0.00:10:00'
          retry: 2
          retryIntervalInSeconds: 30
          secureInput: false
          secureOutput: false
        }
      }
    ]
  }
}

output factoryName string = factory.name
output factoryPrincipalId string = factory.identity.principalId
output pipelineName string = pipeline.name
