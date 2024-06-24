#!/usr/bin/env pwsh
param
(
  [parameter(Mandatory = $true)] [String] $workspaceUrlOrId,
  [parameter(Mandatory = $true)] [String] $env,
  [parameter(Mandatory = $false)] [String] $bundleDirectory = "$PSScriptRoot/../../databricks",  
  [parameter(Mandatory = $false)] [switch] $validate = $false
)
$ErrorActionPreference = "Stop"
$DirectorySplitChar = [System.IO.Path]::DirectorySeparatorChar 
$Env:DATABRICKS_CONFIG_FILE = "${PSScriptRoot}${DirectorySplitChar}databrickscfg.toml"
$Env:DATABRICKS_CONFIG_PROFILE = $env

if ($workspaceUrlOrId -notlike "http*") {
  Write-Host "Deploying using Azure RM Authentication"
"[$Env:DATABRICKS_CONFIG_PROFILE]
azure_workspace_resource_id = $workspaceUrlOrId" | Out-File -FilePath $Env:DATABRICKS_CONFIG_FILE
} else {  
  Write-Host "Deploying to $workspaceUrlOrId using Databricks Auth"  
"[$Env:DATABRICKS_CONFIG_PROFILE]
host = $workspaceUrlOrId" | Set-Content $Env:DATABRICKS_CONFIG_FILE -NoNewLine
}

# Check if databricks.exe is in the path and run it if it is
if (!(Get-Command -Name "databricks" -ErrorAction SilentlyContinue)) {
  Write-Host "databricks is not in the path, installing the CLI in a subfolder and setting temporary path"  
  & "$PSScriptRoot\Install-DatabricksCLI.ps1" -RegisterPathInCurrentSession
}

Write-Host "Searching $bundleDirectory for bundles..."

# Resolve Pool Identifiers
$pools = & databricks instance-pools list --output json | ConvertFrom-Json

# Find all databricks asset bundle files in the repository databricks.yml
$databricksBundleFiles = Get-ChildItem -Path $bundleDirectory -Filter "databricks.yml" -Recurse -File
$databricksBundleFiles | Foreach-Object { Write-Host "Found the following bundle : $($_.Directory.FullName)"} 
foreach ($bundle in $databricksBundleFiles) {
  Write-Host "validate bundle $($bundle.FullName)"
  $directory = Split-Path -Path $bundle.FullName -Parent  

  # Collect all the bundle files in our resources directory.
  $bundleFiles = Get-ChildItem -Path $directory -Filter "*.yml" -Recurse -File | Where-Object { $_.FullName -like '*resources\*' } 

  # Do the deployment  
  if ($validate) {
    Write-Host "Validating $directory..."
    Push-Location $directory
    & databricks bundle validate
    Pop-Location
  }
  else {
    Write-Host "Deploying $directory..."
    Push-Location $directory
    & databricks bundle deploy -t $env
    Pop-Location
  }
}

