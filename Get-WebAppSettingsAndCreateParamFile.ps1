# TO BE USED MANUALLY
Function Get-WebAppSettingFromAzure {
    param(
        $pathToFiles,
        [string[]] $Subscriptions,
        $resourceGroup
    )
    $webAppsWithSettings = @()
    foreach ($subscription in $Subscriptions) {
        Write-Host "For subscription $subscription"
        Set-AzContext -SubscriptionId $subscription | Out-Null
        $webApplications = Get-AzWebApp -ResourceGroupName $resourceGroup

        foreach ($webApp in $webApplications) {
            # need to query it again, strangly `Get-AzureRmWebApp` alone is not returning app settings
            $prod = Get-AzWebAppSlot -ResourceGroupName $webApp.ResourceGroup -Name $webApp.Name -Slot production

            $entry = New-Object System.Object
            $entry | Add-Member -type NoteProperty -name ResourceGroup -value $webApp.resourceGroup
            $entry | Add-Member -type NoteProperty -name AppName -value $webApp.name
            $entry | Add-Member -type NoteProperty -name Kind -value $webApp.Kind
            $entry | Add-Member -type NoteProperty -name AppSettings -value $prod.SiteConfig.AppSettings

            try {
                # Fail silently when there's no staging slot
                $stag = Get-AzWebAppSlot -ResourceGroupName $webApp.ResourceGroup -Name $webApp.Name -Slot staging -ErrorAction SilentlyContinue
                $entry | Add-Member -type NoteProperty -name AppSettingsStaging -value $stag.SiteConfig.AppSettings
                $entry | Add-Member -type NoteProperty -name ConnectionStringsStaging -value $stag.SiteConfig.ConnectionStrings
            }
            catch {
            }
            $webAppsWithSettings += $entry
        }
    }
    return $webAppsWithSettings;
}


Function Get-WebAppSettingFromTemplateAndMergeWithAzure() {
    param(
        [string] $pathToFiles,
        [string] $environment,
        [string] $client,
        [string] $webAppFilter = "app_services_and_plans.param.*.json",
        $webAppsWithSettings
    )
    $allApps = Get-ChildItem "$($pathToFiles)\app_services_and_plans\" -Filter "$webAppFilter"
    $allApps |
        Foreach-Object {
        $newWebsites = @();    
        $content = (Get-Content -Raw -Path $_.FullName | ConvertFrom-Json)
        foreach ($website in $content.parameters.apps.value) {
                
            $webApp = $webAppsWithSettings | Where-Object { $_.AppName -eq "$client-$environment-$($website.name)-as" -or $_.AppName -eq "$client-$environment-$($website.name)-fa" }
        
            if ($webApp -ne $null){
                $settingObject = New-Object System.Object
                $stickySettingObject = New-Object System.Collections.ArrayList
                foreach ($setting in $website.appSettings.sticky_app_settings) {
                    $stickySettingObject.Add($setting)
                }
                $settingObject | Add-Member -type NoteProperty -name sticky_app_settings -value $stickySettingObject

                $prodSettingObject = New-Object System.Object
                $prodSettingObject | Add-Member -type NoteProperty -name "WEBSITE_LOCAL_CACHE_OPTION" -value "Always"
                $prodSettingObject | Add-Member -type NoteProperty -name "WEBSITE_LOCAL_CACHE_SIZEINMB" -value "300"
                $prodSettingObject | Add-Member -type NoteProperty -name "WEBSITE_LOAD_CERTIFICATES" -value "*"

                foreach ($setting in $webApp.AppSettings) {
                $prodSettingObject | Add-Member -type NoteProperty -name $setting.Name -value $setting.Value
            }

            $settingObject | Add-Member -type NoteProperty -name production -value $prodSettingObject

            if ($webApp.AppSettingsStaging) {

                $stagingSettingObject = New-Object System.Object
                $stagingSettingObject | Add-Member -type NoteProperty -name "WEBSITE_LOAD_CERTIFICATES" -value "*"
                foreach ($setting in $webApp.AppSettingsStaging) {
                    $stagingSettingObject | Add-Member -type NoteProperty -name $setting.Name -value $setting.Value
                }
                $settingObject | Add-Member -type NoteProperty -name staging -value $stagingSettingObject
            }
        
            $mergedVersion = New-Object PSObject -Property ([ordered]@{
                    name                  = $website.name
                    kind                  = $website.kind
                    hostingPlan           = $website.hostingPlan
                    clientAffinityEnabled = $website.clientAffinityEnabled
                    hasDeploymentSlot     = $website.hasDeploymentSlot
                    httpsOnly             = $website.httpsOnly  
                    appSettings           = $settingObject
                    siteProperties        = $website.siteProperties
                });

            $newWebsites += $mergedVersion;
            }
        }
        Invoke-UpdateTemplate -websites $newWebsites -originalFilePath $_.FullName -destinationFilePath $_.FullName
    }
}

Function Invoke-UpdateTemplate {
    param(
        $websites,
        $originalFilePath,
        $destinationFilePath
    )
    $content = (Get-Content -Raw -Path $originalFilePath | ConvertFrom-Json)   
    $content.parameters.apps.value = $websites; 
    Set-Content -Value ($content | ConvertTo-Json -Depth 10) -Path $destinationFilePath
}

Login-AzureRmAccount
$Subscription = "00000-0000-000-00000-0000" 
$environment = "qa"
$client = "abc"
$resourceGroup = "$client-$environment-rg"
$webAppFilter = "app_services_and_plans.param.$environment.json"


$pathToFiles = "C:\code\AzureResources\ARM"
$webAppsWithSettings = Get-WebAppSettingFromAzure -Subscriptions $Subscription -resourceGroup $resourceGroup
Get-WebAppSettingFromTemplateAndMergeWithAzure -pathToFiles $pathToFiles -webAppsWithSettings $webAppsWithSettings -environment $environment -client $client -webAppFilter $webAppFilter
