Some examples of the commands used.

```
az blueprint export --name contoso-corp --output-path .
az blueprint import --input-path . --name contoso-corp
az blueprint publish --blueprint-name contoso-corp --version 0.2

Set-Content not-allowed-locations-policy.json -Value ""

$subscriptionId = (az account show --query id --output tsv)
$blueprintId = (az blueprint version show --blueprint-name contoso-corp --version 0.2 | ConvertFrom-Json).id

az blueprint assignment create --subscription $subscriptionId --name contoso-corp --location centralus --identity-type SystemAssigned --blueprint-version $blueprintId --parameters "{}" --locks-mode AllResourcesDoNotDelete
```