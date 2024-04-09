#!/usr/bin/env pwsh
param
(
  [parameter(Mandatory = $true)] [String] $workspaceUrlOrId,
  [parameter(Mandatory = $true)] [String] $env,
  [parameter(Mandatory = $false)] [String] $bundleDirectory = "$PSScriptRoot/../../databricks",  
  [parameter(Mandatory = $false)] [switch] $validate = $false
)
$ErrorActionPreference = "Stop"
$Env:DATABRICKS_CONFIG_FILE = "$PSScriptRoot\databrickscfg.toml"
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

  # Check the bundles for valid instance pool or driver pools references.
  # It can be easier to specify the name so if somebody has done this convert it to an identifier.
  foreach ($bundle in $bundleFiles) {    
    # Find all instance pool references (shared cluster pools)
    $instance_pool_id_pattern = '(instance_pool_id|driver_instance_pool_id):\s+(\S+)'
    $content = (Get-Content -path $bundle.FullName)
    # Check the content of the bundle to see if it has any instance pool references
    $pool_matches = [regex]::Matches($content, $instance_pool_id_pattern)    
    foreach ($match in $pool_matches) {
      # This resolves to the value that instance_pool_id is currently set to.
      $potential_pool_match = $match.Groups[2].Value
      # This resolves to the full line that we potentially will be replacing
      $replacement_string_lookup = $match.Groups[0].Value
      $job_match = ($pools | Where-Object instance_pool_name -eq $potential_pool_match) | Select-Object -First 1
      if ($job_match) {
        # We have a pool that matches the name set in instance_pool_id, lets replace it.
        $replacement_string = $replacement_string_lookup.Replace($job_match.instance_pool_name, $job_match.instance_pool_id)
        Write-Host("Replacing [$replacement_string_lookup] with [$replacement_string]")
        $content.Replace($replacement_string_lookup, $replacement_string) | Set-Content $bundle.FullName -Force
      }
      else {
        $job_id = ($pools | Where-Object instance_pool_id -eq $potential_pool_match) | Select-Object -First 1
        if (!$job_id) {
          Write-Warning "Could not find the identifier ${potential_pool_match} provided in the bundle ${bundle}, bundle deployment may fail"
        }        
      }
    }
  }

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

