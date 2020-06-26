Import-Module .\Monitoring\TemplateGenerator -Force

$config = Get-Configuration -ConfigPath "C:\Code\AzureResources\Monitoring"

Invoke-CreateOrUpdateGrafanaDashboards @config
#azure login handled by devops agent task