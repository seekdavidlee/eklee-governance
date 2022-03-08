@allowed([
  'dev'
  'prod'
])
param stackEnvironment string
param location string = 'centralus'
param principalId string
param contributorRoleId string
param blueprintName string
param prefix string

// Configure Azure Blueprint Bicep on the Subscription level.
targetScope = 'subscription'

var sharedServicesName = 'sharedservices-${stackEnvironment}'
var keyVaultViewerName = 'keyvault-viewer-${stackEnvironment}'
var contributorRoleIdRes = '/providers/Microsoft.Authorization/roleDefinitions/${contributorRoleId}'

// All resources created by the blueprint should use this tag.
var sharedServicesTags = {
  'stack-name': 'platform'
  'stack-environment': stackEnvironment
  'stack-sub-name': 'sharedservices'
}

var keyVaultViewerTags = {
  'stack-name': 'keyvault-viewer'
  'stack-environment': stackEnvironment
}

resource blueprint 'Microsoft.Blueprint/blueprints@2018-11-01-preview' = {
  name: blueprintName
  properties: {
    description: '${blueprintName} blueprint'
    displayName: blueprintName
    parameters: {}
    resourceGroups: {
      ResourceGroup1: {
        name: sharedServicesName
        location: location
        tags: sharedServicesTags
        metadata: {
          displayName: sharedServicesName
        }
      }
      ResourceGroup2: {
        name: keyVaultViewerName
        location: location
        tags: keyVaultViewerTags
        metadata: {
          displayName: keyVaultViewerName
        }
      }
    }
    targetScope: 'subscription'
  }
}

resource resourceGroupRole1Assignment 'Microsoft.Blueprint/blueprints/artifacts@2018-11-01-preview' = {
  name: 'resource-group-1-role-assignment'
  kind: 'roleAssignment'
  parent: blueprint
  properties: {
    displayName: 'Service Principal : Contributor'
    principalIds: [
      principalId
    ]
    resourceGroup: 'ResourceGroup1'
    roleDefinitionId: contributorRoleIdRes
  }
}

resource resourceGroupRole2Assignment 'Microsoft.Blueprint/blueprints/artifacts@2018-11-01-preview' = {
  name: 'resource-group-2-role-assignment'
  kind: 'roleAssignment'
  parent: blueprint
  properties: {
    displayName: 'Service Principal : Contributor'
    principalIds: [
      principalId
    ]
    resourceGroup: 'ResourceGroup2'
    roleDefinitionId: contributorRoleIdRes
  }
}

// Well-know policy defination: e56962a6-4747-49cd-b67b-bf8b01975c4c - Allowed locations

resource allowedLocations 'Microsoft.Blueprint/blueprints/artifacts@2018-11-01-preview' = {
  name: 'sub-not-allowed-location-assignment'
  kind: 'policyAssignment'
  parent: blueprint
  properties: {
    displayName: 'Allowed locations'
    description: 'The list of locations that can be specified when deploying resources.'
    policyDefinitionId: tenantResourceId('Microsoft.Authorization/policyDefinitions', 'e56962a6-4747-49cd-b67b-bf8b01975c4c')
    parameters: {
      listOfAllowedLocations: {
        value: [
          'centralus'
          'eastus2'
          'northcentralus'
          'southcentralus'
          'eastus'
          'westus'
        ]
      }
    }
  }
}

var stackName = '${prefix}${stackEnvironment}'

// Configure Shared Azure Key Vault resource
resource sharedKeyVault 'Microsoft.Blueprint/blueprints/artifacts@2018-11-01-preview' = {
  name: 'shared-key-vault'
  kind: 'template'
  parent: blueprint
  properties: {
    description: 'Shared keyvault resource used to store any application specific secrets used in configurations'
    displayName: 'Shared keyvault'
    parameters: {}
    resourceGroup: 'ResourceGroup1'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      resources: [
        {
          name: stackName
          type: 'Microsoft.KeyVault/vaults'
          apiVersion: '2021-11-01-preview'
          location: location
          tags: sharedServicesTags
          properties: {
            sku: {
              name: 'standard'
              family: 'A'
            }
            enableSoftDelete: false
            enableRbacAuthorization: true
            enabledForTemplateDeployment: true
            enablePurgeProtection: true
            tenantId: subscription().tenantId
          }
        }
      ]
    }
  }
}

// Configure user identities to represents apps hosted in each of the resource group that
// can be used to access Shared resources like Key Vault.
var users = [
  {
    rg: 'ResourceGroup2'
    name: 'akv'
    tags: keyVaultViewerTags
  }
]

resource usersDefs 'Microsoft.Blueprint/blueprints/artifacts@2018-11-01-preview' = [for (user, i) in users: {
  kind: 'template'
  name: user.name
  parent: blueprint
  properties: {
    description: 'Managed user identity for apps hosted in ${user.rg}'
    displayName: 'User identity.'
    parameters: {}
    resourceGroup: user.rg
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      resources: [
        {
          name: user.name
          type: 'Microsoft.ManagedIdentity/userAssignedIdentities'
          apiVersion: '2018-11-30'
          location: location
          tags: user.tags
        }
      ]
    }
  }
}]
