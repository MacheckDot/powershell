<#
.SYNOPSIS
    A script that collects all information about Entra ID groups and membership. 

.DESCRIPTION
    The scripts collect all groups with members and properties, then the result is exported to JSON file.  

.PARAMETER directoryPath
    Directory in which output file will be saved. If left blank, then output file will be saved in the current directory.

.EXAMPLE
    .\\CollecGroups.ps1 -directoryPath 'C:\temp'
#>

param (
    [string]$directoryPath
)

# Check Graph connection
try {
	if (-not (Get-MgContext)) {
		Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All","Directory.Read.All"-NoWelcome # Directory.Read.All access is neccessary to read assigned roles to groups

	}
} catch {
	Write-Error "Failed to connect to Microsoft Graph: $_"
	exit
}

$directoryRoleAssignement = @()
$directoryRoleAssignement = Get-MgRoleManagementDirectoryRoleAssignment
$tenantId = (Get-MgOrganization).Id
# Pagination function
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

function Get-Roles {
    param (
        [string]$groupId
    )
    $roles = $directoryRoleAssignement | Where-Object {$_.PrincipalId -eq $group.Id} 
    $roles = $roles | Select -Property RoleDefinitionId
    return $roles
}
function Get-LicenseSku {
    param (
        [string]$groupId
    )

    $group = Get-MgGroup -GroupId $groupId -Property "AssignedLicenses"
    $assignedLicenses = $group | Select-Object -ExpandProperty AssignedLicenses
    $skuIds = $assignedLicenses | Select-Object -ExpandProperty SkuId
    return $skuIds
}

$groups = Get-AllPages -Command { Get-MgGroup -All:$true }

$groupList = @()

foreach ($group in $groups) {
    try {
       
        $owners = Get-AllPages -Command { Get-MgGroupOwner -GroupId $group.Id }
        $ownerNames = $owners | ForEach-Object { $_.AdditionalProperties.displayName }

        $members = Get-AllPages -Command { Get-MgGroupMember -GroupId $group.Id }
        $memberDetails = $members | ForEach-Object {
            [PSCustomObject]@{
                DisplayName = $_.AdditionalProperties.displayName
                Id          = $_.Id
            }
        }

        $groupProperties = [PSCustomObject]@{
            Owner               = $ownerNames -join ", "
            Description         = $group.Description
            DirSyncEnabled      = $group.DirSyncEnabled
            DisplayName         = $group.DisplayName
            LastDirSyncTime     = $group.LastDirSyncTime
            Mail                = $group.Mail
            MailEnabled         = $group.MailEnabled
            MailNickName        = $group.MailNickname
            SecurityEnabled     = $group.SecurityEnabled
            GroupTypes          = $group.GroupTypes
            AssigndLicensesSku  = Get-LicenseSku -groupId $group.Id
            AssignedRoles       = Get-Roles -groupId $group.Id
            Members             = $memberDetails
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
