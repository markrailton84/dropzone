$locations="eastus","westus2"
#$dateTimeStamp = $(Get-Date -Format "dd-MM-yyyy" )
#$logLocationInput = $(Get-Location)
#$logLocation = New-Item -Path $logLocationInput -Name "testlog-$dateTimeStamp.log" -ItemType "file" -Value ""

foreach ($i in $locations){
    $randomIdentifier=$(Get-Random)
    write-output "Location: $i"
    write-output ""
    $resourceGroupName="rsg-$i-$randomIdentifier"
    write-output "Resource Group Name: $resourceGroupName"
    write-output ""
    az group create --name $resourceGroupName --location $i
    write-output "Deploying CosmosDb - cosmosdb-$i-$randomIdentifier"
    write-output ""
    az cosmosdb create --name cosmosdb-$i-$randomIdentifier --resource-group $resourceGroupName
    #$cosmosDbCreate=$(az cosmosdb create --name cosmosdb-$i-$randomIdentifier --resource-group $resourceGroupName)
<#     if (!$cosmosDbCreate) {
        Write-Error "Error creating CosmosDB account in region $i - cosmosdb-$i-$randomIdentifier"
        return #>
    # Start-Sleep -Seconds 30    
    # delete resources
    write-output "Deleting CosmosDb - cosmosdb-$i-$randomIdentifier"
    write-output "" 
    az cosmosdb delete --name "cosmosdb-$i-$randomIdentifier" --resource-group $resourceGroupName
    write-output "Deleting Resource Group - $resourceGroupName"
    write-output ""    
    az group delete -n $resourceGroupName
}