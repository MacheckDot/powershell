<#
.SYNOPSIS

#>

param (
    [string]$directoryPath
)

# Check Graph connection
try {
	if (-not (Get-MgContext)) {
		Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All" -NoWelcome -ErrorAction Break
	}
} catch {
	Write-Error "Failed to connect to Microsoft Graph: $_"
	exit
}

$tenantId = (Get-MgOrganization).Id
#pagination handler
function Get-AllPages {
    param (
        [scriptblock]$Command
    )
    $results = @()
    $page = & $Command
    while ($page) {
        $results += $page
        if ($page.OdataNextLink) {
            $uri = $page.OdataNextLink
            $page = Invoke-MgGraphRequest -Uri $uri -Method GET
        } else {
            break
        }
    }
    return $results
}

$groups = Get-AllPages -Command { Get-MgGroup -All:$true }

$groupList = @()

foreach ($group in $groups) {
    try {
        # Get group owners with pagination
        $owners = Get-AllPages -Command { Get-MgGroupOwner -GroupId $group.Id }
        $ownerNames = $owners | ForEach-Object { $_.AdditionalProperties.displayName }

        # Get group members with pagination and include display name + ID
        $members = Get-AllPages -Command { Get-MgGroupMember -GroupId $group.Id }
        $memberDetails = $members | ForEach-Object {
            [PSCustomObject]@{
                DisplayName = $_.AdditionalProperties.displayName
                Id          = $_.Id
            }
        }

        $groupProperties = [PSCustomObject]@{
            Owner           = $ownerNames -join ", "
            Description     = $group.Description
            DirSyncEnabled  = $group.DirSyncEnabled
            DisplayName     = $group.DisplayName
            LastDirSyncTime = $group.LastDirSyncTime
            Mail            = $group.Mail
            MailEnabled     = $group.MailEnabled
            MailNickName    = $group.MailNickname
            SecurityEnabled = $group.SecurityEnabled
            GroupTypes      = $group.GroupTypes
            Members         = $memberDetails
        }

        $groupObject = [PSCustomObject]@{
            Name            = $group.DisplayName
            ObjectId        = $group.Id
            Properties      = $groupProperties
        }

        $groupList += $groupObject
    } catch {
        Write-Warning "Failed to process group '$($group.DisplayName)' (ID: $($group.Id)): $_"
        continue
    }
}


$outputObject = [PSCustomObject]@{
    TenantId = $tenantId
    Groups   = $groupList
}


[string]$today = Get-Date -Format dd_MM_yyyy


$directoryPath = if ($directoryPath) { [string]::Concat($directoryPath, '\') } else { ".\" }
$baseFileName = "groups_$today"
$extension = ".json"
$counter = 0

do {
    $fileName = if ($counter -eq 0) { "$baseFileName$extension" } else { [string]::Concat($baseFileName,"_$counter",$extension) }
    $filePath = [System.IO.Path]::Combine($directoryPath, $fileName)
    $counter++
} while (Test-Path $filePath)

try {
    $outputObject | ConvertTo-Json -Depth 5 | Out-File -FilePath $filePath -Encoding UTF8
    Write-Output "JSON data saved to $filePath"
} catch {
    Write-Error "Failed to save JSON data to $filePath : $_"
}
