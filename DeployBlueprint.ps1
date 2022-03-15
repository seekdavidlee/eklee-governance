# Use this script to deploy Blueprint which will create the necessary resource groups in your environment
# and assigning the Contributor role to the Service principal in those resource groups.

# 1. Versioning is built into the script and you can add a switch to indicate a major or minor change.
# 2. Change notes is based on last git change log.

param(
    [Parameter(Mandatory = $true)][string]$BUILD_ENV,
    [Parameter(Mandatory = $true)][string]$PRINCIPAL_ID,
    [Parameter(Mandatory = $true)][string]$PREFIX,
    [switch]$Major,
    [switch]$Minor)

   
$ErrorActionPreference = "Stop"

if (((az extension list | ConvertFrom-Json) | Where-Object { $_.name -eq "blueprint" }).Length -eq 0) {
    az extension add --upgrade -n blueprint    
}

$blueprintName = "corp$BUILD_ENV"

$subscriptionId = (az account show --query id --output tsv)
if ($LastExitCode -ne 0) {
    throw "An error has occured. Subscription id query failed."
}

$contributorRoleId = (az role definition list --name "Contributor" | ConvertFrom-Json).name

az deployment sub create --name "deploy-$blueprintName-blueprint" --location 'centralus' --template-file blueprint.bicep `
    --subscription $subscriptionId `
    --parameters stackEnvironment=$BUILD_ENV principalId=$PRINCIPAL_ID `
    contributorRoleId=$contributorRoleId blueprintName=$blueprintName prefix=$PREFIX

if ($LastExitCode -ne 0) {
    throw "An error has occured. Deployment failed."
}

$versions = (az blueprint version list --blueprint-name $blueprintName | ConvertFrom-Json)
if ($LastExitCode -ne 0) {
    throw "An error has occured. Version query failed."
}

if (!$versions -or $versions.Length -eq 0) {
    $appliedVersion = '0.1'
}
else {
    $lastVersions = $versions[$versions.Length - 1].name.Split('.')
    $lastMajor = [int]$lastVersions[0]
    $lastMinor = [int]$lastVersions[1]

    if (!$Major -and !$Minor) {
        $lastMinor += 1
    }
    else {

        if ($Major) {
            $lastMajor += 1
        }

        if ($Minor) {
            $lastMinor += 1
        }
    }
    $appliedVersion = "$lastMajor.$lastMinor"
}


$msg = (git log --oneline -n 1)

$blueprintJson = az blueprint publish --blueprint-name $blueprintName --version $appliedVersion --change-notes $msg --subscription $subscriptionId

if ($LastExitCode -ne 0) {
    throw "An error has occured. Publish failed."
}

$blueprintId = ($blueprintJson | ConvertFrom-Json).id

$assignmentName = "assign-$blueprintName-$appliedVersion"

az blueprint assignment create --subscription $subscriptionId --name $assignmentName `
    --location centralus --identity-type SystemAssigned --blueprint-version $blueprintId `
    --parameters "{}" --locks-mode AllResourcesDoNotDelete

if ($LastExitCode -ne 0) {
    throw "An error has occured. Assignment failed."
}

az blueprint assignment wait --subscription $subscriptionId --name $assignmentName --created
if ($LastExitCode -ne 0) {
    throw "An error has occured. Assignment failed (wait)."
}

# This portion of the script handles the role assignments between the managed identities and shared resources.
$ids = az identity list | ConvertFrom-Json

if ($LastExitCode -ne 0) {
    throw "An error has occured. Identity listing failed."
}

$platformRes = (az resource list --tag stack-name=platform | ConvertFrom-Json)
if (!$platformRes) {
    throw "Unable to find eligible platform resource!"
}

if ($platformRes.Length -eq 0) {
    throw "Unable to find 'ANY' eligible platform resource!"
}

# Platform specific Azure Key Vault as a Shared resource
$akvid = ($platformRes | Where-Object { $_.type -eq 'Microsoft.KeyVault/vaults' -and $_.tags.'stack-environment' -eq $BUILD_ENV }).id

$ids | ForEach-Object {

    $id = $_
    az role assignment create --assignee $id.principalId --role 'Key Vault Secrets User' --scope $akvid
    if ($LastExitCode -ne 0) {
        throw "An error has occured on $stackName assignment."
    }
}