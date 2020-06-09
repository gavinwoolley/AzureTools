Import-Module $env:Pipeline_Workspace/PowerShellModulesArtifact/Deployment

$config = @{
    TemplateName        = "private_dns_zones"
    Environment         = $env:Environment_Name
    targetResourceGroup = "test-rg"
}

Invoke-GenericDeployment @config
