#!/usr/bin/env pwsh
param (
    [string]$GroupName,
    [string]$AccountId,
    [ValidateSet("add", "remove")]
    [string]$Operation = "add"
)

if (!$GroupName) {
    Read-Host "Please enter the existing group name you would like to designate as an administrative group (https://accounts.azuredatabricks.net/users/groups)"
}
if (!$AccountId) {
    Read-Host "Please enter the databricks account identifier (this can be found by clicking in the top right hand corner (https://accounts.azuredatabricks.net)"
}

$urlBase = "https://accounts.azuredatabricks.net/api/2.0/accounts/$AccountId/scim/v2/"
# Get the access token so the Azure CLI can talk to the Azure Databricks Instance
try { 
    $token = (az account get-access-token --resource=2ff814a6-3304-4ab8-85cb-cd0e6f879c1d --query accessToken --output tsv)
}
catch { "An error occurred, do you have a databricks instance deployed? Is the Azure CLI installed (https://learn.microsoft.com/en-us/cli/azure/install-azure-cli), Have you run 'az login'?" }

# Find the existing Azure AD Group
$findGroupQuery = "$($urlBase)/Groups?filter=displayName eq '$GroupName'"

$groupInformation = Invoke-RestMethod -Uri $findGroupQuery `
    -Method Get `
    -Headers @{Authorization = "Bearer $token" } 

if ($groupInformation.totalResults -ne 1) {
    Write-Error "Unable to find single group with name '$GroupName' ($findGroupQuery)"
}

$groupId = $groupInformation.Resources.id

$body = @"
{
  "schemas": [
    "urn:ietf:params:scim:api:messages:2.0:PatchOp"
  ],
  "Operations": [{"op":"$Operation","path":"roles","value":[{"value":"account_admin"}]}]
}
"@

(Invoke-RestMethod -Uri "$($urlBase)/Groups/$groupId" `
    -Headers @{Authorization = "Bearer $token" } `
    -Method Patch `
    -Body $body `
    -ContentType application/json) | Format-List