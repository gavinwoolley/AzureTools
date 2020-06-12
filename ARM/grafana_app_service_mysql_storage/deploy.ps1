# Set Names
$app_service_name = "grafana-test-app"  
$storage_account_name = "gavstoragegrafana"
$mysql_server_name = "test-mysql-grafana"
$ResourceGroupName = "test-rg"
$Subscription = "CSS-DevOps00"

$config = @{
    DeploymentName        = "Gavin-Test-Grafana"
    ResourceGroupName     = $ResourceGroupName
    TemplateFile          = "C:\Code\AzureTools\ARM\grafana_app_service_mysql_storage\grafana_app_service_mysql_storage.json"
    TemplateParameterFile = "C:\Code\AzureTools\ARM\grafana_app_service_mysql_storage\grafana_app_service_mysql_storage.param.json"
    app_service_name      = $app_service_name
    storage_account_name  = $storage_account_name
    mysql_server_name     = $mysql_server_name 
}

#Connect-AzAccount 

Set-AzContext -Subscription $Subscription

New-AzResourceGroupDeployment @config

# Also need to copy the certificate to the storage
$ctx = (Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storage_account_name).Context  
$key = Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storage_account_name | Where-Object { $_.KeyName -eq "key1" }

## Get the file share  
$fileShareName = "grafana"
$certFile = "BaltimoreCyberTrustRoot.crt.pem"
$certFilePath = "C:\Code\AzureTools\ARM\grafana_app_service_mysql_storage"
$fileShare = Get-AZStorageShare -Context $ctx -Name $fileShareName  

## Upload the file  
Set-AzStorageFileContent -Share $fileShare -Source "$certFilePath\$certFile" -Path $certFile -Force  

#Add storage mount to app service with AZ command 
#az login
az webapp config storage-account add --resource-group $ResourceGroupName `
    --name $app_service_name `
    --custom-id "grafana"  `
    --storage-type AzureFiles `
    --account-name $storage_account_name  `
    --share-name "grafana" `
    --access-key $key.Value `
    --mount-path "/var/lib/grafana" `
    --subscription $Subscription