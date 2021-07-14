# Powershell script - VHDX conversion to VHD
# Notes:
# 1. Convert VHDX to VHD
# 2. Upload VHD to Storage Account - Blob - Container

# pre-reqs

# Install the AzureRM.BootStrapper module. Select Yes when prompted to install NuGet
Install-Module -Name AzureRM.BootStrapper

# Install and import the API Version Profile required by Azure Stack Hub into the current PowerShell session.
Use-AzureRmProfile -Profile 2019-03-01-hybrid -Force
Install-Module -Name AzureStack -RequiredVersion 1.8.3

# variable delcared

$rgName = "resourceGroupName"
$azureVhdName = "someNameHere"
$containerUrl = "urlHere"
$localVhdName = "pathForLocalVhd"

# upload VHD to Azure

add-azurermvhd -resourceGroupName $rgName -destination $containerUrl -localfilepath $localVhdName