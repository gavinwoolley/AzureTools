Import-Module $env:Pipeline_Workspace/PowerShellModulesArtifact/Deployment

$config = @{
    TemplateName = "dns_zones"
    Environment = $env:Environment_Name
    targetResourceGroup = "xos-mgmt-rg"
}

Invoke-GenericDeployment @config
