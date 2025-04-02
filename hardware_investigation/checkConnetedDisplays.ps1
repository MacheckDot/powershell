<#
.SYNOPSIS
    A script that gather all relevant information about connected monitors

.DESCRIPTION
    This script uses CIM instances to retive data about active monitors and collect saved monitors data from registry and saved EDID data.

.PARAMETER Format
    Select format output: List or Table. If skipped, output is in RAW format of PS Object

.EXAMPLE
    .\\checkConnectedDisplays.ps1 -Format List
    
#>
param(
    [ValidateSet('List','Table')]
    [string]$Format
)
<#
Win32_PnPEntity 
Availability: Indicates the availability and status of the device.
Caption: A short description of the object.
ClassGuid: The globally unique identifier (GUID) for the device class.
CompatibleID: An array of compatible IDs for the device.
ConfigManagerErrorCode: The error code reported by the configuration manager.
Description: A textual description of the object.
DeviceID: The unique identifier for the device.
HardwareID: An array of hardware IDs for the device.
Manufacturer: The name of the device manufacturer.
Name: The name of the device.
PNPDeviceID: The Plug and Play device identifier.  <- to może być przydatne
Service: The name of the service that supports the device.
Status: The current status of the object.
SystemName: The name of the system on which the object is installed.
#>
function Convert-EDIDToReadable {
    param (
        [byte[]]$EDID
    )
    # converts EDID from bytes to readable format ans stores it in the PS Object
    $productCode = "{0:X4}" -f ($EDID[10] -bor ($EDID[11] -shl 8))
    $serialNumber = "{0:X8}" -f ($EDID[12] -bor ($EDID[13] -shl 8) -bor ($EDID[14] -shl 16) -bor ($EDID[15] -shl 24))
    $weekOfManufacture = $EDID[16]
    $yearOfManufacture = 1990 + $EDID[17]
    $version = $EDID[18]
    $revision = $EDID[19]
    $horizontalSize = $EDID[21]
    $verticalSize = $EDID[22]
    $supportedResolutions = @()
    for ($i = 54; $i -lt 126; $i += 18) {
        $pixelClock = ($EDID[$i] -bor ($EDID[$i + 1] -shl 8)) * 10
        if ($pixelClock -eq 0) { continue }

        $hActive = ($EDID[$i + 2] -bor (($EDID[$i + 4] -band 0xF0) -shl 4))
        $vActive = ($EDID[$i + 5] -bor (($EDID[$i + 7] -band 0xF0) -shl 4))
        $supportedResolutions += "{0}x{1} @ {2}kHz" -f $hActive, $vActive, $pixelClock
    }

    $edidInfo = [PSCustomObject]@{
        ProductCode = $productCode
        SerialNumber = $serialNumber
        WeekOfManufacture = $weekOfManufacture
        YearOfManufacture = $yearOfManufacture
        EDIDVersion = $version
        EDIDRevision = $revision
        ScreenSize = "{0}cm x {1}cm" -f $horizontalSize, $verticalSize
        SupportedResolutions = $supportedResolutions
    }

    return $edidInfo
}

# check registry for all salved displays info, extract EDID and create PS Object with all gathered data
$baseRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY"
$monitorInfoArray = @()

$subKeys = Get-ChildItem -Path $baseRegistryPath

# retrieve all Win32_PnPEntity and WmiMonitorBasicDisplayParams instances once
$pnPEntities = Get-CimInstance -ClassName Win32_PnPEntity | Where-Object {$_.DeviceID -like "DISPLAY*"}
$monitorParams = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams

foreach ($subKey in $subKeys) {
    $displayName = $subKey.PSChildName
    $deviceSubKeys = Get-ChildItem -Path $subKey.PSPath

    foreach ($deviceSubKey in $deviceSubKeys) {
        $subKeyName = $deviceSubKey.PSChildName
        $deviceParametersPath = "$($deviceSubKey.PSPath)\Device Parameters"

        if (Test-Path -Path $deviceParametersPath) {
            $registryValues = Get-ItemProperty -Path $deviceParametersPath
            $edidInfo = Convert-EDIDToReadable -EDID $registryValues.EDID
            $pnPEntity = $pnPEntities | Where-Object { $_.DeviceID -like "DISPLAY\$displayName\$subKeyName*" }
            $monitorParam = $monitorParams | Where-Object { $_.InstanceName -like "DISPLAY\$displayName\$subKeyName*" }

            $monitorInfo = [PSCustomObject]@{
                Name = $pnPEntity.Name
                DisplayID = $displayName
                DeviceIDSubKey = $subKeyName
                EDID = $registryValues.EDID
                ProductCode = $edidInfo.ProductCode
                SerialNumber = $edidInfo.SerialNumber
                WeekOfManufacture = $edidInfo.WeekOfManufacture
                YearOfManufacture = $edidInfo.YearOfManufacture
                EDIDVersion = $edidInfo.EDIDVersion
                EDIDRevision = $edidInfo.EDIDRevision
                ScreenSize = $edidInfo.ScreenSize
                Supportedresolutions = $edidInfo.SupportedResolutions
                Active = $monitorParam.Active
                Availability = $pnPEntity.Availability
                Status = $pnPEntity.Status
                ErrorCleared = $pnPEntity.ErrorCleared
                ErrorDescription = $pnPEntity.ErrorDescription
                Service = $pnPEntity.Service
            }

            $monitorInfoArray += $monitorInfo
        } else {
            Write-Output "Device Parameters key not found for: $deviceParametersPath"
        }
    }
}
# format output
if ($format -eq 'List'){
    return $monitorInfoArray | Format-List 
    }
elseif ($format -eq 'Table') {
    return $monitorInfoArray | Format-Table -AutoSize 
    } 
else { return $monitorInfoArray }
