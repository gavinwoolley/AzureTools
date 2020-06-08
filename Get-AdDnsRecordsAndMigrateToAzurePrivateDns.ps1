#Login-AzAccount
#$subscriptionId = "" #devops-oo
#$ResourceGroupName = "PrivateDnsTest"
#Select-AzSubscription -SubscriptionId  $subscriptionId

#Install-Module AZ

#$zones = Get-DnsServerZone
#$zones = $zones | Where-Object -Property isreverselookupzone -ne "true"
foreach ($zone in $zones) {
    $dnsr = Get-DnsServerResourceRecord $zone.ZoneName
    
    #New-AzPrivateDnsZone -Name $zone.ZoneName -ResourceGroupName $ResourceGroupName 
    
    #Get NS record for new DNS Zone 
    #$NS = Get-AzDnsRecordSet -ResourceGroupName $ResourceGroupName -ZoneName $zone.ZoneName -RecordType NS
    
    #Set each record from Windows DNS Server to Azure DNS Zone
    Foreach ($r in $dnsr) {
        if ($r.RecordType -eq "MX") {
            $MXinfo = Get-AzPrivateDnsRecordSet -ResourceGroupName $ResourceGroupName -ZoneName $zone.ZoneName -Name $r.Hostname -RecordType $r.RecordType
            if ($MXinfo -eq $null) {
                $MXinfo = New-AzPrivateDnsRecordConfig -Exchange $r.RecordData.MailExchange -Preference $r.RecordData.Preference 
                New-AzPrivateDnsRecordSet -Name $r.Hostname -RecordType $r.RecordType -ZoneName $zone.ZoneName -Ttl $r.TimeToLive.TotalSeconds -ResourceGroupName $ResourceGroupName -PrivateDnsRecord $MXinfo | Out-Null
            }
            Else {
                Add-AzPrivateDnsRecordConfig -Exchange $r.RecordData.MailExchange -Preference $r.RecordData.Preference -RecordSet $MXinfo | Out-Null
                Set-AzPrivateDnsRecordSet -RecordSet $MXinfo -Overwrite | Out-Null
            }
        }
        if ($r.RecordType -eq "A") {
            $Ainfo = Get-AzPrivateDnsRecordSet -ResourceGroupName $ResourceGroupName -ZoneName $zone.ZoneName -Name $r.Hostname -RecordType $r.RecordType
            if ($Ainfo -eq $null) {
                $Ainfo = New-AzPrivateDnsRecordConfig -Ipv4Address $r.RecordData.IPv4Address.IPAddressToString
                New-AzPrivateDnsRecordSet -Name $r.Hostname -RecordType $r.RecordType -ZoneName $zone.ZoneName -Ttl $r.TimeToLive.TotalSeconds -ResourceGroupName $ResourceGroupName -PrivateDnsRecord $Ainfo | Out-Null
            }
            Else {
                Add-AzPrivateDnsRecordConfig -Ipv4Address $r.RecordData.IPv4Address.IPAddressToString -RecordSet $Ainfo | Out-Null
                Set-AzPrivateDnsRecordSet -RecordSet $Ainfo -Overwrite  | Out-Null
            }
        }
        if ($r.RecordType -eq "AAAA") {
            $AAAAinfo = Get-AzPrivateDnsRecordSet -ResourceGroupName $ResourceGroupName -ZoneName $zone.ZoneName -Name $r.Hostname -RecordType $r.RecordType
            if ($AAAAinfo -eq $null) {
                $AAAAinfo = New-AzPrivateDnsRecordConfig -Ipv6Address $r.RecordData.IPv6Address.IPAddressToString
                New-AzPrivateDnsRecordSet -Name $r.Hostname -RecordType $r.RecordType -ZoneName $zone.ZoneName -Ttl $r.TimeToLive.TotalSeconds -ResourceGroupName $ResourceGroupName -PrivateDnsRecord $AAAAinfo | Out-Null
            }
            Else {
                Add-AzPrivateDnsRecordConfig -Ipv6Address $r.RecordData.IPv6Address.IPAddressToString -RecordSet $AAAAinfo | Out-Null
                Set-AzPrivateDnsRecordSet -RecordSet $AAAAinfo -Overwrite | Out-Null
            }
        }
        if ($r.RecordType -eq "SRV") {
            $SRVinfo = Get-AzPrivateDnsRecordSet -ResourceGroupName $ResourceGroupName -ZoneName $zone.ZoneName -Name $r.Hostname -RecordType $r.RecordType
            if ($SRVinfo -eq $null) {
                $SRVinfo = New-AzPrivateDnsRecordConfig -Port $r.RecordData.Port -Priority $r.RecordData.Priority -Target $r.RecordData.DomainName -Weight $r.RecordData.Weight
                New-AzPrivateDnsRecordSet -Name $r.Hostname -RecordType $r.RecordType -ZoneName $zone.ZoneName -Ttl $r.TimeToLive.TotalSeconds -ResourceGroupName $ResourceGroupName -PrivateDnsRecord $SRVinfo | Out-Null
            }
            Else {
                Add-AzPrivateDnsRecordConfig -Port $r.RecordData.Port -Priority $r.RecordData.Priority -Target $r.RecordData.DomainName -Weight $r.RecordData.Weight -RecordSet $SRVinfo | Out-Null
                Set-AzPrivateDnsRecordSet -RecordSet $SRVinfo -Overwrite | Out-Null
            }
        }
        if ($r.RecordType -eq "TXT") {
            $TXTinfo = Get-AzPrivateDnsRecordSet -ResourceGroupName $ResourceGroupName -ZoneName $zone.ZoneName -Name $r.Hostname -RecordType $r.RecordType
            if ($TXTinfo -eq $null) {
                $TXTinfo = New-AzPrivateDnsRecordConfig -Value $r.RecordData.DescriptiveText
                New-AzPrivateDnsRecordSet -Name $r.Hostname -RecordType $r.RecordType -ZoneName $zone.ZoneName -Ttl $r.TimeToLive.TotalSeconds -ResourceGroupName $ResourceGroupName -PrivateDnsRecord $TXTinfo | Out-Null
            }
            Else {
                Add-AzPrivateDnsRecordConfig -Value $r.RecordData.DescriptiveText -RecordSet $TXTinfo | Out-Null
                Set-AzPrivateDnsRecordSet -RecordSet $TXTinfo -Overwrite | Out-Null
            }
        }
        if ($r.RecordType -eq "CNAME") {
            $CNAMEinfo = New-AzPrivateDnsRecordConfig -Cname $r.RecordData.HostNameAlias
            New-AzPrivateDnsRecordSet -Name $r.Hostname -RecordType $r.RecordType -ZoneName $zone.ZoneName -Ttl $r.TimeToLive.TotalSeconds -ResourceGroupName $ResourceGroupName -PrivateDnsRecord $CNAMEinfo | Out-Null
        }
        if ($r.RecordType -eq "PTR") {
            $PTRinfo = Get-AzPrivateDnsRecordSet -ResourceGroupName $ResourceGroupName -ZoneName $zone.ZoneName -Name $r.Hostname -RecordType $r.RecordType
            if ($PTRinfo -eq $null) {
                $PTRinfo = New-AzPrivateDnsRecordConfig -Ptrdname $r.RecordData.PtrDomainName
                New-AzPrivateDnsRecordSet -Name $r.Hostname -RecordType $r.RecordType -ZoneName $zone.ZoneName -Ttl $r.TimeToLive.TotalSeconds -ResourceGroupName $ResourceGroupName -PrivateDnsRecord $PTRinfo | Out-Null
            }
            Else {
                Add-AzPrivateDnsRecordConfig -Ptrdname $r.RecordData.PtrDomainName -RecordSet $PTRinfo | Out-Null
                Set-AzPrivateDnsRecordSet -RecordSet $PTRinfo -Overwrite | Out-Null
            }
        }
    }
    Write-Host
    Write-Host -ForegroundColor Cyan "Please add NS records below to domain Registrar to complete cut over........"
    $ns.Records.nsdname
}
    