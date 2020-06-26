function Invoke-CreateOrUpdateGrafanaDashboards {
    param(
        [Parameter(Mandatory = $true)]
        [array] $config
    )

    Set-AzContext -Subscription $config.subscriptionId | Out-Null
    $resources = Get-AzResource -ResourceGroupName "$($config.organisation)-$($config.environment)-rg"

    #Filter Resources
    
    #Create Dashboard Model
    $environment = $config.environment
    $DashboardObject = Build-GrafanaDashboardModel -environment $environment
    $DashboardObject = Add-GrafanaDashboardDeploymentAnnotationsToModel -environment $environment -DashboardObject $DashboardObject

    #Post New Dashboard Request
    Invoke-DashboardUpload -apiKey $config.grafanaApiKey `
        -grafanaUrl $config.grafanaUrl `
        -dashboard $DashboardObject
}

function Build-GrafanaDashboardModel {
    param(
        [array] $resources,
        [Parameter(Mandatory = $true)]
        [array] $environment
    )
    
    $DashboardModel = New-Object System.Object 
    $DashboardObject = New-Object System.Object
    $AnnotationsModel = New-Object System.Object
    $PanelsModel = @()
    $TagsModel = @()

    $DashboardModel | Add-Member -type NoteProperty -name annotations -value $AnnotationsModel
    $DashboardModel | Add-Member -type NoteProperty -name panels -value $PanelsModel
    $DashboardModel | Add-Member -type NoteProperty -name tags -value $TagsModel
    $DashboardModel | Add-Member -type NoteProperty -name title -value "$environment - Web Apps"
    $DashboardModel | Add-Member -type NoteProperty -name uid -value $null

    $DashboardObject | Add-Member -type NoteProperty -name dashboard -value $DashboardModel

    return $DashboardObject
}

function Add-GrafanaDashboardDeploymentAnnotationsToModel {
    param (
        [Parameter(Mandatory = $true)]
        [System.Object] $DashboardObject,
        [Parameter(Mandatory = $true)]
        [array] $environment
    )

    $AnnotationsModel = New-Object System.Object
    $AnnotationsModel | Add-Member -type NoteProperty -name datasource -value "-- Grafana --"
    $AnnotationsModel | Add-Member -type NoteProperty -name enable -value $true
    $AnnotationsModel | Add-Member -type NoteProperty -name hide -value $false
    $AnnotationsModel | Add-Member -type NoteProperty -name iconColor -value "rgba(255, 96, 96, 1)"
    $AnnotationsModel | Add-Member -type NoteProperty -name matchAny -value $true
    $AnnotationsModel | Add-Member -type NoteProperty -name name -value "Deployments"
    $AnnotationsModel | Add-Member -type NoteProperty -name showIn -value 0
    $TagsModel = @($environment)
    $AnnotationsModel | Add-Member -type NoteProperty -name tags -value $TagsModel
    $AnnotationsList = @()
    $AnnotationsList += $AnnotationsModel

    $DashboardObject.dashboard.annotations | Add-Member -type NoteProperty -name list -value $AnnotationsList -Force

    #annotations needs to be in a list
    return $DashboardObject
}

function Get-Configuration {
    param (
        [string] $ConfigPath = $PSScriptRoot
    )

    $configPath = Resolve-Path (Join-Path -Path $ConfigPath -ChildPath '\Configuration')

    if ($env:SYSTEM -eq "build") {
        $config = Get-Content -Path $configPath\appsettings.json | ConvertFrom-Json
    }
    else {
        $config = Get-Content -Path $configPath\appsettings.gitignore.json | ConvertFrom-Json
    }

    return $config
}

function Invoke-DashboardUpload {
    param(
        [Parameter(Mandatory = $true)]
        [string] $apiKey,
        [Parameter(Mandatory = $true)]
        [string] $grafanaUrl,
        [Parameter(Mandatory = $true)]
        [System.Object] $dashboard
    )

    $headers = @{
        Authorization = "Bearer $($apiKey)"
    }

    $dash = $dashboard | Select-Object -Property dashboard

    Add-Member -InputObject $dash `
        -MemberType NoteProperty `
        -Name "overwrite" `
        -Value $true

    Add-Member -InputObject $dash `
        -MemberType NoteProperty `
        -Name "folderId" `
        -Value 22

    $content = $dash  | ConvertTo-Json -Depth 50

    Invoke-RestMethod -Method POST `
        -Headers $headers `
        -UseBasicParsing `
        -ContentType application/json `
        -Uri "$($grafanaUrl)/api/dashboards/db" `
        -Body $content
}

Export-ModuleMember -Function @(
    "Invoke-CreateOrUpdateGrafanaDashboards"
    "Get-Configuration"
)