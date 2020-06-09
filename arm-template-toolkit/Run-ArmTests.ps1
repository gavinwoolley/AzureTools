[CmdletBinding()] 
param(
    [string]$templateLocation,
    [string]$resultLocation
)
 
Import-Module "$PSScriptRoot\arm-ttk\arm-ttk.psd1"
Import-Module "$PSScriptRoot\modules\Export-NUnitXml.psm1" -Force
Import-Module "$PSScriptRoot\modules\invoke-ttk.psm1" -Force

Invoke-TTK -templateLocation $templateLocation -resultLocation $resultLocation
