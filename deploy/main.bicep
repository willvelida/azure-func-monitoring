@description('Name that will be used to build associated artifacts')
param applicationName string = uniqueString(resourceGroup().id)

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of the storage account provisioned for use by the Function')
param storageAccountName string = toLower('${applicationName}sa')

@description('The SKU for the storage account. Default is Standard_LRS')
param storageSku string = 'Standard_LRS'

@description('The name of the app service plan that we will deploy our Function to')
param appServicePlanName string = toLower('${applicationName}-asp')

@description('The name of the Function App that we will deploy.')
param functionAppName string = toLower('${applicationName}-fa')

@description('The name of the App Insights instance that this function will send logs to')
param appInsightsName string = toLower('${applicationName}-ai')

@description('The name of the Log Analytics workspace that will be deployed')
param logAnalyticsWorkspaceName string = toLower('${applicationName}-law')

@description('The name of the Service Bus Namespace that will be deployed')
param serviceBusNamespaceName string = toLower('sb${applicationName}')

@description('Name of the Cosmos DB account that will be deployed')
param cosmosDBAccountName string = toLower('${applicationName}db')

@description('The name of the database in this Cosmos DB account')
param databaseName string = 'OrderDB'

@description('The name of the container in this Cosmos DB account')
param containerName string = 'orders'

@description('The time that the resource was last deployed')
param lastDeployed string = utcNow()

@description('The name of the order queue for Service Bus')
param ordersQueueName string = 'orders'

var functionRuntime = 'dotnet-isolated'
var serviceBusOwnerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '090c5cfd-751d-490a-894a-3ce6f1109419')
var serviceBusDataReceiverRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions','4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0')
var serviceBusDataSenderRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions','69a216fc-b8fb-44d8-bc22-1f3c2cd27a39')
var tags = {
  Application: 'azufunc-monitoring'
  LastDeployed: lastDeployed
  Environment: 'Production'
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: storageSku
  }
  kind: 'Storage'
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  tags: tags
  location: location
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
  }
  properties: {
    maximumElasticWorkerCount: 20
  }
  kind: 'elastic'
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource ordersQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  name: ordersQueueName
  parent: serviceBus
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: cosmosDBAccountName
  location: location
  tags: tags
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-05-15' = {
  name: databaseName
  parent: cosmosAccount
  properties: {
    resource: {
      id: databaseName
    }
    options: {
      throughput: 400
    }
  }
}

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2022-05-15' = {
  name: containerName
  parent: database
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
      }
    }
  }
}

resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  tags: tags
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${appInsights.properties.InstrumentationKey}'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionRuntime
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'ServiceBusConnection__fullyQualifiedNamespace'
          value: '${serviceBus.name}.servicebus.windows.net'
        }
        {
          name: 'ServiceBusEndpoint'
          value: '${serviceBus.name}.servicebus.windows.net'
        }
        {
          name: 'CosmosDbEndpoint'
          value: cosmosAccount.properties.documentEndpoint
        }
        {
          name: 'QueueName'
          value: ordersQueue.name
        }
        {
          name: 'DatabaseName'
          value: database.name
        }
        {
          name: 'ContainerName'
          value: container.name
        }
      ]
    }
    httpsOnly: true
  }
}

resource functionAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: functionApp.name
  scope: functionApp
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource serviceBusOwnerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceBus.id, functionApp.id, serviceBusOwnerRoleId)
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: serviceBusOwnerRoleId
    principalType: 'ServicePrincipal'
  }
}

resource serviceBusReceiverRole 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(serviceBus.id, functionApp.id, serviceBusDataReceiverRole)
  scope: serviceBus
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: serviceBusDataReceiverRole
    principalType: 'ServicePrincipal'
  }
}

resource serviceBusSenderRole 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(serviceBus.id, functionApp.id, serviceBusDataSenderRole)
  scope: serviceBus
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: serviceBusDataSenderRole
    principalType: 'ServicePrincipal'
  }
}

module sqlRoleAssignment 'modules/sql-role-assignment.bicep' = {
  name: 'sqlRoleAssignment'
  params: {
    cosmosDbAccountName: cosmosAccount.name
    functionAppPrincipalId: functionApp.identity.principalId
  }
}
