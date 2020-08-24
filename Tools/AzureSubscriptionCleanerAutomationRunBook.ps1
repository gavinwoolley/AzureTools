#Manual Exclusions for now 
$ResourceGroupsToExclude = @(
    "DevOps"
    "NetworkWatcherRG"
)

$connectionName = "AzureRunAsConnection"

try {
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

    Connect-AzAccount `
        -ServicePrincipal `
        -Tenant $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
        
    $context = Get-AzContext
    $subName = $context.Subscription.Name

    Write-Output "Logged into Azure subscription $subName"
}
catch {
    if (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    }
    else {
        Write-Error -Message $_.Exception 
        throw $_.Exception
    }
}

$AllResourceGroups = Get-AzResourceGroup;

$ResourceGroupsToRemove = $AllResourceGroups | Where-Object { $_.ResourceGroupName -notin $ResourceGroupsToExclude } | Select-Object ResourceGroupName

foreach ($resourceGroup in $ResourceGroupsToRemove) {
    $ResourceGroupName = $resourceGroup.ResourceGroupName;
    $ResourcesToRemove = Get-AzResource -ResourceGroupName $ResourceGroupName;
    foreach ($Resource in $ResourcesToRemove) {
        Write-Output "Removing Resource : $($Resource.name)"
        Remove-AzResource -ResourceId $Resource.id -Force
    }
    Write-Output "Removing ResourceGroup : $ResourceGroupName "
    Remove-AzResourceGroup -Name $ResourceGroupName -Force
}