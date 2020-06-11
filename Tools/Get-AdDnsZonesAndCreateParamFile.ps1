# TO BE USED MANUALLY
Function Get-AdDnsZonesAndRecords {

    $zones = Get-DnsServerZone
    $ZonesAndRecords = @()
    foreach ($zone in $zones) {
        $mxRecords = @()
        $ARecords = @()
        $AAAARecords = @()
        $TxtRecords = @()
        $SrvRecords = @()
        $cNameRecords = @()
        $PtrRecords = @()

        Write-Host "Working on Zone $($zone.ZoneName)"
        $entry = New-Object System.Object
        $entry | Add-Member -type NoteProperty -name ZoneName -value $zone.ZoneName

        $DnsRecords = Get-DnsServerResourceRecord $zone.ZoneName
        foreach ($record in $DnsRecords) {
            if ($record.RecordType -eq "MX") {      
                $mx = New-Object System.Object
                $mx | Add-Member -type NoteProperty -name TTL -value $record.TimeToLive.TotalSeconds    
                $records = New-Object System.Object
                $records | Add-Member -type NoteProperty -name Exchange -value $record.RecordData.MailExchange
                $records | Add-Member -type NoteProperty -name Preference -value $record.RecordData.Preference
                $mx | Add-Member -type NoteProperty -name records -value $records
                $mxRecords += $mx
            }
            if ($record.RecordType -eq "A") {
                $a = New-Object System.Object
                $a | Add-Member -type NoteProperty -name name -value $record.Hostname
                $ipv4 = New-Object System.Object
                $ipv4 | Add-Member -type NoteProperty -name Ipv4Address -value $record.RecordData.IPv4Address.IPAddressToString
                $ipv4records = @()
                $ipv4records += $ipv4
                $a | Add-Member -type NoteProperty -name records -value $ipv4records
                $a | Add-Member -type NoteProperty -name TTL -value $record.TimeToLive.TotalSeconds    
                $ARecords += $a
            }
            if ($record.RecordType -eq "SRV") {
                $srv = New-Object System.Object
                $srv | Add-Member -type NoteProperty -name name -value $record.Hostname
                $srv | Add-Member -type NoteProperty -name port -value $record.RecordData.Port
                $srv | Add-Member -type NoteProperty -name priority -value $record.RecordData.Priority
                $srv | Add-Member -type NoteProperty -name target -value $record.RecordData.DomainName
                $srv | Add-Member -type NoteProperty -name weight -value $record.RecordData.Weight
                $srv | Add-Member -type NoteProperty -name TTL -value $record.TimeToLive.TotalSeconds    
                $SrvRecords += $srv
            }
            if ($record.RecordType -eq "TXT") {
                $txt = New-Object System.Object
                $txt | Add-Member -type NoteProperty -name name -value $record.Hostname
                $txt | Add-Member -type NoteProperty -name TTL -value $record.TimeToLive.TotalSeconds    
                $records = New-Object System.Object
                $records | Add-Member -type NoteProperty -name value -value $record.RecordData.DescriptiveText
                $txt | Add-Member -type NoteProperty -name records -value $records    
                $TxtRecords += $txt
            }
            if ($record.RecordType -eq "CNAME") {
                $cname = New-Object System.Object
                $cname | Add-Member -type NoteProperty -name name -value $record.Hostname
                $cname | Add-Member -type NoteProperty -name alias -value $record.RecordData.HostNameAlias
                $cname | Add-Member -type NoteProperty -name ttl -value $record.TimeToLive.TotalSeconds    
                $cNameRecords += $cname
            }
            if ($record.RecordType -eq "PTR") {
                $ptr = New-Object System.Object
                $ptr | Add-Member -type NoteProperty -name Hostname -value $record.Hostname
                $ptr | Add-Member -type NoteProperty -name Ptrdname -value $record.RecordData.PtrDomainName
                $ptr | Add-Member -type NoteProperty -name RecordType -value $record.RecordType
                $ptr | Add-Member -type NoteProperty -name Ttl -value $record.TimeToLive.TotalSeconds    
                $PtrRecords += $ptr
            }
        }
        $entry | Add-Member -type NoteProperty -name mxRecords -value $mxRecords
        $entry | Add-Member -type NoteProperty -name ARecords -value $ARecords
        $entry | Add-Member -type NoteProperty -name AAAARecords -value $AAAARecords
        $entry | Add-Member -type NoteProperty -name SrvRecords -value $SrvRecords
        $entry | Add-Member -type NoteProperty -name TxtRecords -value $TxtRecords
        $entry | Add-Member -type NoteProperty -name cNameRecords -value $cNameRecords
        $entry | Add-Member -type NoteProperty -name PtrRecords -value $PtrRecords
        $ZonesAndRecords += $entry
    }
    return $ZonesAndRecords;
}


Function Build-AzurePrivateDnsParamFile() {
    param(
        [string] $pathToFolder,
        $ZonesAndRecords
    )

    foreach ($Zone in $ZonesAndRecords) {
        $newZoneFile = @();   

        $environmentObject = New-Object System.Object
        $environmentObject | Add-Member -type NoteProperty -name value -value "Global"

        $buildverObject = New-Object System.Object
        $buildverObject | Add-Member -type NoteProperty -name value -value "1.0.0"
 
        $vNetLinkRecords = @()
        $vNetLink = New-Object System.Object
        $vNetLink | Add-Member -type NoteProperty -name vNetNameToLink -value "test-vnet-1"   
        $vNetLinkRecords += $vNetLink
        $vNetLink = New-Object System.Object
        $vNetLink | Add-Member -type NoteProperty -name vNetNameToLink -value "test-vnet-2"   
        $vNetLinkRecords += $vNetLink

        $vNetLinksObject = New-Object System.Object
        $vNetLinksObject | Add-Member -type NoteProperty -name value -value $vNetLinkRecords
 
        $parametersObject = New-Object System.Object
        
        $zoneNameObject = New-Object System.Object
        $aRecordsObject = New-Object System.Object
        $cNameRecordsObject = New-Object System.Object
        $mxRecordsObject = New-Object System.Object
        $txtRecordsObject = New-Object System.Object
        $srvRecordsObject = New-Object System.Object

        $zoneNameObject | Add-Member -type NoteProperty -name value -value $zone.ZoneName
        $aRecordsObject | Add-Member -type NoteProperty -name value -value $zone.ARecords
        $cNameRecordsObject | Add-Member -type NoteProperty -name value -value $zone.cNameRecords
        $mxRecordsObject | Add-Member -type NoteProperty -name value -value $zone.MXRecords
        $txtRecordsObject | Add-Member -type NoteProperty -name value -value $zone.TxtRecords
        $srvRecordsObject | Add-Member -type NoteProperty -name value -value $zone.srvRecords   

        $parametersObject | Add-Member -type NoteProperty -name ZoneName -value $zoneNameObject
        $parametersObject | Add-Member -type NoteProperty -name cnames -value $cNameRecordsObject
        $parametersObject | Add-Member -type NoteProperty -name aRecords -value $aRecordsObject
        $parametersObject | Add-Member -type NoteProperty -name mxRecords -value $mxRecordsObject
        $parametersObject | Add-Member -type NoteProperty -name txtRecords -value $txtRecordsObject
        $parametersObject | Add-Member -type NoteProperty -name srvRecords -value $srvRecordsObject 
        $parametersObject | Add-Member -type NoteProperty -name vNetLinks -value $vNetLinksObject             
        $parametersObject | Add-Member -type NoteProperty -name environment -value $environmentObject                
        $parametersObject | Add-Member -type NoteProperty -name buildver -value $buildverObject             

        $mergedVersion = New-Object PSObject -Property ([ordered]@{
                '$schema'      = "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#"
                contentVersion = "1.0.0.0"
                parameters     = $parametersObject
            });

        $newZoneFile += $mergedVersion;
            
        Invoke-CreateParameterFile -zone $newZoneFile -pathToFolder $pathToFolder
    }
}

Function Invoke-CreateParameterFile {
    param(
        $zone,
        $pathToFolder
    )
    $zoneName = $zone.parameters.ZoneName.value
    Set-Content -Value ($zone | ConvertTo-Json -Depth 10) -Path "$pathToFolder\private_dns_zones.param.global.$zoneName.json"
}

$pathToFolder = "C:\code\"
$ZonesAndRecords = Get-AdDnsZonesAndRecords
Build-AzurePrivateDnsParamFile -pathToFolder $pathToFolder -ZonesAndRecords $ZonesAndRecords 