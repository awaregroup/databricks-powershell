#!/usr/bin/env pwsh
param([switch]$RegisterPathInCurrentSession)

# Copyright (c) Aware Group Ltd.
# Licensed under the MIT License.

$ErrorActionPreference = "Stop"

$VERSION = "0.212.3" # Bump this version for newer versions
$FILE = "databricks_cli_$VERSION"
$TARGET = "$PSScriptRoot/databricks-cli"

# Include operating system in file name.
if (($Env:OS -eq "Windows_NT") -or $IsWindows ) {
    $FILE = "${FILE}_windows"
} elseif ($IsMacOS) {
    $FILE = "${FILE}_darwin"
} else {
    $FILE = "${FILE}_linux"
}

if ($FILE -eq "databricks_cli_$VERSION") {
    Write-Warning "Unknown operating system: $Env:OS"
    exit 1
}

$FILE = "${FILE}_amd64"

New-Item -ItemType Directory -Force -Path $TARGET
# Download release archive.
Invoke-WebRequest -Uri "https://github.com/databricks/cli/releases/download/v${VERSION}/${FILE}.zip" -OutFile "${FILE}.zip"

# Unzip release archive.
Expand-Archive -Path "${FILE}.zip" -DestinationPath $TARGET -Force

Remove-Item "${FILE}.zip"

if ($IsLinux -or $IsMacOS) {
    & chmod +x "$TARGET/databricks"
}

if ($RegisterPathInCurrentSession) {
    if (($Env:OS -eq "Windows_NT") -or $IsWindows ) {
         $Env:Path += [IO.Path]::PathSeparator + $TARGET
    }
    else {
        $Env:PATH += [IO.Path]::PathSeparator + $TARGET
    }
}
