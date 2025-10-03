<#
.SYNOPSIS
    Script to change Windows Language for Windows 11 autopilot revices. 
    Author: Maciej Pawiński

.DESCRIPTION
    The script downloads selected Language package, and then update all necessary setings related to Language. 
    It is possbile to save current input methods with variable SaveLanguageInput.

.PARAMETER Language
    Deisred languege in bcp47 tag format. 

.PARAMETER GeoID
    Geol location of the computer, it's used to set region and time of the system.
    Check in LINKS for GeoID documentation.

.PARAMETER SaveLanguageInput
    For saving current keyboard input method. Default value is set to false.

.EXAMPLE
    .\\Set-AutopilotDeviceLanguage -Language en-US -GeoID 0xf4 -SaveLanguageInput $true

.LINK
    Valid GeoID: https://learn.microsoft.com/en-gb/windows/win32/intl/table-of-geographical-locations?redirectedfrom=MSDN
#>

#Requires -RunAsAdministrator

param (
    [Parameter(Mandatory=$true)]
    [string]
    $Language,

    [Int32]
    $GeoID = 0xbf, #default value for Poland
    
    [bool]
    $SaveLanguageInput = $false
)

#check if OS is Windows 11
$WindowsVersion = ((Get-CimInstance win32_operatingsystem | Select-Object Version).Version).Split('.')[-1]
if (-not ($WindowsVersion -gt 22000)) {   
    Write-Host "Unable to run the script. The OS version is too old. Please update OS to Windows 11!"
    Break Script
}

#collect already installed language packages
[string[]]$CurrentLanguage
$CurrentLanguage = (Get-WmiObject -Class Win32_OperatingSystem).MUILanguages

if (-not($CurrentLanguage -contains $Language)) {
    Write-Host "Trying to Install Language: ..."
    Install-Language -Language $Language -CopyToSettings -ErrorAction Continue
} 
else {
    Write-Host "$Language is already installed. Skipping package installation..."
}

if ($SaveLanguageInput) {
    $OldLanguageList = Get-WinUserLanguageList 
    $OldLanguageList.Add($Language)
    Set-WinUserLanguageList -LanguageList $OldLanguageList -force
}

Set-SystempreferredUILanguage $Language -ErrorAction SilentlyContinue
Set-WinUILanguageOverride -Language $Language
Set-WinSystemLocale -SystemLocale $Language
Set-Culture $Language
Set-WinHomeLocation -GeoId $GeoID
Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
