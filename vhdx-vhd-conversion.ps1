# Powershell script - VHDX conversion to VHD
# Notes:
# 1. Convert VHDX to VHD
# 2. Upload VHD to Storage Account - Blob - Container

# variable delcared

$rgName = "resourceGroupName"
$azureVhdName = "someNameHere"
$containerUrl = "urlHere"
$localVhdName = "pathForLocalVhd"

# upload VHD to Azure

add-azurermvhd -resourceGroupName $rgName -destination $containerUrl -localfilepath $localVhdName