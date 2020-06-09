function Invoke-GenericDeployment {
    param(
        [Parameter(Mandatory = $true)]
        [string] $TemplateName,
        [string] $Environment,
        [string] $targetResourceGroup
    )

    try {
        $BuildNumber = $env:Build_BuildNumber
        $templateFile = "$($TemplateName).json"
        $filesToDeploy = @()
        $parameterFileFilter = "$($TemplateName).param.$($Environment)*.json"

        $filesToDeploy = Get-ChildItem $env:pipeline_workspace -Filter $parameterFileFilter -Recurse -Depth 2 | ForEach-Object { @{
            TemplateFile  = "$($_.Directory)/$($templateFile)"
            ParameterFile = "$($_.Directory)/$($_.Name)"
        } }

        $deploymentName = "$TemplateName.$Environment.$BuildNumber"

        foreach ($fileset in $filesToDeploy) {
            $parameterFile = $fileSet.ParameterFile

            if ([string]::IsNullOrWhiteSpace($parameterFile)) {
                $parameterFile = $fileset.TemplateFile
            }

            Write-Output "Deploying the following:"
            Write-Output "Deployment Name: $($deploymentName)"
            Write-Output "Target Resource Group: $($targetResourceGroup)"
            Write-Output "Template: $($fileset.TemplateFile)"
            Write-Output "Parameter file: $($fileset.ParameterFile)"

            Test-TemplateDeploy -ResourceGroupName $targetResourceGroup `
                -TemplateFile $fileset.TemplateFile `
                -ParameterFile $fileset.ParameterFile
  
            Invoke-TemplateDeploy -DeploymentName $deploymentName `
                -ResourceGroupName $targetResourceGroup `
                -TemplateFile $fileset.TemplateFile `
                -ParameterFile $fileset.ParameterFile
        }
    }
    catch {
        Write-Host "An error occured during deployment:"
        Write-Host $_
        Write-Host $_.Exception.Message
        Write-Host $_.Exception.StackTrace

        throw "Deploy failed"
    }
}

function Test-TemplateDeploy {
    param(
        [parameter(Mandatory = $true)]
        [string] $ResourceGroupName,
        [parameter(Mandatory = $true)]
        [string] $TemplateFile,
        [string] $ParameterFile
    )

    if (-not (Test-Path -Path $TemplateFile)) {
        throw "Unable to find template file '$($TemplateFile)'"
    }

    Write-Output "Testing ARM template deployment to resource group $($ResourceGroupName)"

    $errors = $null

    if ([string]::IsNullOrWhiteSpace($ParameterFile)) {
        $errors = Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile
    }
    else {
        if (-not (Test-Path -Path $ParameterFile)) {
            throw "Unable to find parameter file '$ParameterFile'"
        }
        $errors = Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile -TemplateParameterFile $ParameterFile
    }

    if ($errors.Count -gt 0) {
        foreach ($templateError in $errors) {
            Write-Output "$($templateError.Code) $($templateError.Message)"
            Write-Output $templateError.Details
        }

        throw "Template failed testing, aborting"
    }
}

function Invoke-TemplateDeploy {
    param(
        [parameter(Mandatory = $true)]
        [string] $DeploymentName,
        [parameter(Mandatory = $true)]
        [string] $ResourceGroupName,
        [parameter(Mandatory = $true)]
        [string] $TemplateFile,
        [string] $ParameterFile
    )

    if (-not (Test-Path -Path $TemplateFile)) {
        throw "Unable to find $($TemplateFile)"
    }

    Write-Output "Running ARM template deployment for $($DeploymentName) to resource group $($ResourceGroupName)"

    $status = $null

    if ([string]::IsNullOrWhiteSpace($ParameterFile)) {
        Write-Output "Deploying template without parameter file"
        $status = New-AzResourceGroupDeployment -DeploymentName $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile
    }
    else {
        Write-Output "Deploying template with parameter file '$($ParameterFile)'"
        $status = New-AzResourceGroupDeployment -DeploymentName $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile -TemplateParameterFile $ParameterFile
    }

    $operations = Get-AzResourceGroupDeploymentOperation -ResourceGroupName $ResourceGroupName -DeploymentName $DeploymentName

    foreach ($operation in $operations) {
        Write-Output "Resource: $($operation.Properties.TargetResource.ResourceName)"
        Write-Output "State   : $($operation.Properties.ProvisioningState)"
        Write-Output "Status  : $($operation.Properties.StatusCode)"

        if (-not $operation.Properties.StatusCode -eq "OK") {
            Write-Output "Failure reason: $($operation.Properties.StatusMessage.Message)"
        }
    }

    if (-not ($status.ProvisioningState -eq "Succeeded")) {
        throw "Resource group deployment failed whilst deploying $($DeploymentName) to resource group $($ResourceGroupName)"
    }
}

Export-ModuleMember -Function @(
    "Invoke-GenericDeployment"
)