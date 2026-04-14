param(
    [string]
    $ExportDirectory = '.\'

)

try {
    Get-SPOTenant -ErrorAction Stop | Out-Null
}
catch {
    [string]$SPOLoginUrl = Read-Host "Enter SPO Url:"
    Connect-SPOService -Url $SPOLoginUrl -ModernAuth $true -AuthenticationUrl https://login.microsoftonline.com/organizations
}

$FileName ='SPO_groups_report.json' 
$ExportPath = $ExportDirectory + $FileName


$SiteList = New-Object System.Collections.Generic.List[PSObject]
$Sites = Get-SPOSite -Limit all -IncludePersonalSite $false
foreach ($site in $Sites) {
    if(([string]::IsNullOrEmpty($site.Owner))) {
        $siteDetails = New-Object PSObject @{
            SiteTitle = $site.Title
            Url = $site.Url
            Owner = $site.Owner
            LastContentModified = $site.LastContentModifiedDate.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")
            GoupID = $site.GroupId
            TeamsConnected = $site.IsTeamsConnected
            StorageUsed = $site.StorageUsageCurrent.ToString() + " MB"
        }
        $SiteList.Add($siteDetails)      
    }
}
$SitelistJson = ConvertTo-Json -InputObject $SiteList -Depth 2
$SitelistJson | Out-File $ExportPath