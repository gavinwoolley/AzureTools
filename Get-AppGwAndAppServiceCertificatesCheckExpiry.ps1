function Get-AllWebAppCertificates {
    param (
        [Parameter(Mandatory = $true)]
        [int] $FutureDateWindow
    )

    $Subscriptions = Get-AzSubscription 
    $expiredCerts = @()
    foreach ($subscription in $Subscriptions) {
    
        Select-AzSubscription -SubscriptionId $subscription.SubscriptionId | Out-Null
        $resourceGroups = Get-AzResourceGroup

        foreach ($resourceGroup in $resourceGroups) {
            try {
                $certs = Get-AzWebAppCertificate -ResourceGroupName $resourceGroup.ResourceGroupName

                $date = get-date
                $dateWindow = (Get-Date).AddDays($FutureDateWindow)
                $expiredCertsMember = @()

                foreach ($cert in $certs) {
                    if ($cert.expirationDate -le $dateWindow ) {
   
                        $expiredCertsMember = New-Object System.Object
                        $expiredCertsMember | Add-Member -type NoteProperty -name SubjectName -value $cert.SubjectName
                        $expiredCertsMember | Add-Member -type NoteProperty -name ExpirationDate -value $cert.ExpirationDate
                        $expiredCertsMember | Add-Member -type NoteProperty -name Thumbprint -value $cert.Thumbprint
                        $expiredCertsMember | Add-Member -type NoteProperty -name Id -value $cert.Id
                        $expiredCertsMember | Add-Member -type NoteProperty -name Location -value $cert.Location
                        $expiredCertsMember | Add-Member -type NoteProperty -name Issuer -value $cert.Issuer
                        $expiredCertsMember | Add-Member -type NoteProperty -name SubscriptionId -value $subscription.SubscriptionId
                        $expiredCertsMember | Add-Member -type NoteProperty -name ResourceGroupName -value $resourceGroup.ResourceGroupName
                        $expiredCertsMember | Add-Member -type NoteProperty -name Name -value $cert.Name

                        $expiredCerts += $expiredCertsMember
                        Write-host -Fore Green "Found App Service cert with Subject Name $($cert.SubjectName) Issuer: $($cert.Issuer) expiration: $($cert.ExpirationDate) thumbprint: $($cert.Thumbprint) Resource Group Name: $($resourceGroup.ResourceGroupName)"
                    }
                }
            }
            catch {
                $errorMessage = $_.Exception
                Write-Host "An error occured executing the script: $errorMessage"
            }
        }
    }
    return $expiredCerts
}

function Get-AllAppGatewayCertificates {
    param (
        [Parameter(Mandatory = $true)]
        [int] $FutureDateWindow
    )

    $Subscriptions = Get-AzSubscription 
    $expiredAppGwCerts = @()
    foreach ($subscription in $Subscriptions) {
    
        Select-AzSubscription -SubscriptionId $subscription.SubscriptionId | Out-Null
        $AppGateways = Get-AzApplicationGateway 

        foreach ($AppGateway in $AppGateways) {
            try {
                $AppGatewayCerts = Get-AzApplicationGatewaySslCertificate -ApplicationGateway $AppGateway
                
                $date = get-date
                $dateWindow = (Get-Date).AddDays($FutureDateWindow)
                $expiredCertsMember = @()

                foreach ($appGatewayCert in $AppGatewayCerts) {
                    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]([System.Convert]::FromBase64String($appGatewayCert.publicCertData.Substring(60,$appGatewayCert.publicCertData.Length-60)))
                    if ($cert.NotAfter -le $dateWindow ) {
                        $expiredCertsMember = New-Object System.Object
                        $expiredCertsMember | Add-Member -type NoteProperty -name AppGatewayName -value $AppGateway.name
                        $expiredCertsMember | Add-Member -type NoteProperty -name CertName -value $appGatewayCert.Name
                        $expiredCertsMember | Add-Member -type NoteProperty -name ResourceGroupName -value $AppGateway.ResourceGroupName
                        $expiredCertsMember | Add-Member -type NoteProperty -name Issuer -value $cert.Issuer
                        $expiredCertsMember | Add-Member -type NoteProperty -name SubjectNameUnicode -value $cert.DnsNameList.Unicode
                        $expiredCertsMember | Add-Member -type NoteProperty -name SubjectName -value $cert.SubjectName.Name
                        $expiredCertsMember | Add-Member -type NoteProperty -name SubscriptionId -value $subscription.SubscriptionId
                        $expiredCertsMember | Add-Member -type NoteProperty -name NotAfter -value $cert.NotAfter
                        $expiredCertsMember | Add-Member -type NoteProperty -name Thumbprint -value $cert.Thumbprint

                        $expiredAppGwCerts += $expiredCertsMember
                        Write-host -Fore Green "Found App GW cert with Subject Name $($cert.SubjectName.Name) Issuer: $($cert.Issuer) expiration: $($cert.NotAfter) thumbprint: $($cert.Thumbprint) Resource Group Name: $($AppGateway.ResourceGroupName)"
                    }
                }
            }
            catch {
                $errorMessage = $_.Exception
                Write-Host "An error occured executing the script: $errorMessage"
            }
        }
    }
    return $expiredAppGwCerts
}

function Set-NewLetsEncryptCertOnAppGw {
    param (
        [Parameter(Mandatory = $true)]
        $expiredAppGwCerts
    )

    $Length = 12
    $characters = 'abcdefghkmnprstuvwxyz23456789$%&?*+#'
    $PfxPassword = -join ($characters.ToCharArray() | Get-Random -Count $Length) 
        
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module -Name Posh-ACME -Confirm:$False

    $ctx = Get-AzContext
    $token = ($ctx.TokenCache.ReadItems() | ?{ $_.TenantId -eq $ctx.Subscription.TenantId -and $_.resource -eq 'https://management.core.windows.net/'} | Select -First 1).AccessToken

    $azParams = @{
        AZSubscriptionId=$subscriptionID
        AZAccessToken=$token
      }

    foreach ($expiredAppGwCert in $expiredAppGwCerts){

        #check cert not already created first
        $LetsEncryptCerts = Get-PACertificate

        foreach ($LetsEncryptCert in $LetsEncryptCerts) {
            $CertToBeUsed = $LetsEncryptCert | where-object {$LetsEncryptCert.Subject -eq $expiredAppGwCert.SubjectName} 
            Select-AzSubscription -SubscriptionId $expiredAppGwCert.SubscriptionId | Out-Null
            $AppGateway = Get-AzApplicationGateway -Name $expiredAppGwCert.AppGatewayName -ResourceGroupName $expiredAppGwCert.ResourceGroupName
            
            $certDate = Get-Date $CertToBeUsed.NotBefore
            $nowMinus10 = (Get-Date).adddays(-1)

            if($certDate -lt $nowMinus10){
                $LetsEncryptCert = New-PACertificate $expiredAppGwCert.SubjectNameUnicode -AcceptTOS -DnsPlugin Azure -PluginArgs $azParams -PfxPass $PfxPassword -Force 
                Set-AzApplicationGatewaySslCertificate -Name $expiredAppGwCert.CertName -ApplicationGateway $AppGateway -CertificateFile $LetsEncryptCert.PfxFile -Password $PfxPassword | Out-Null
            }
            else {
                $PfxPassword = $LetsEncryptCerts.PfxPass | ConvertFrom-SecureString -AsPlainText
                Set-AzApplicationGatewaySslCertificate -Name $expiredAppGwCert.CertName -ApplicationGateway $AppGateway -CertificateFile $CertToBeUsed.PfxFile -Password $PfxPassword | Out-Null
            }
        }   
    }
}

################### Script Execution Starts Here ###################

#Login with your AAD credentials
Login-AzAccount

#Query all certs in all Subs in all RGs
#Date window is how many days in the future to check for expiry
$expiredCerts = Get-AllWebAppCertificates -FutureDateWindow 40
$expiredAppGwCerts = Get-AllAppGatewayCertificates -FutureDateWindow 40

#Display Certs in output grid for you to confirm results
$expiredCerts | Out-GridView
$expiredAppGwCerts  | Out-GridView

Set-NewLetsEncryptCertOnAppGw -expiredAppGwCerts $expiredAppGwCerts
