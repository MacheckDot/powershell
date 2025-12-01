<#
.SYNOPSIS
    A script that collects all information about Entra ID groups and membership. 
    Autor: Maciej Pawiński

.DESCRIPTION
    The scripts collect all groups with members and properties. T result is exported to JSON file.  

.PARAMETER OutputDirectory
    Directory in which output file will be saved. If left blank, then output file will be saved in the current directory.

.EXAMPLE
    .\\CollecGroups.ps1 -OutputDirectory 'C:\temp'
#>

param (
    [string]$OutputDirectory
)

$RequiredModules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Groups",
    "Microsoft.Graph.Identity.SignIns",
    "Microsoft.Graph.Identity.Governance"
)

Write-Host "Checking required Microsoft Graph modules..."

foreach ($module in $RequiredModules) {
    if (-not (Get-InstalledModule -Name $module -ErrorAction SilentlyContinue)) {
        Write-Warning "$module is not installed. Installing..."
        try {
            Install-Module -Name $module -Scope CurrentUser -Force -ErrorAction Stop
            Write-Host "$module installed successfully."
        }
        catch {
            Write-Error "Failed to install $module : $_"
            exit 1
        }
    }
}
Write-Host "All modules installed, checking connection to Microosft Graph..."
#Check Graph connection
try {
	if (-not (Get-MgContext)) {
		Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All","RoleManagement.Read.Directory" -NoWelcome
        Write-Host "Connected to Microsoft Graph..."
	}
} catch {
	Write-Error "Failed to connect to Microsoft Graph: $_"
	exit
}

function Export-Output {
    [string]$currentDate = Get-Date -Format dd_MM_yyyy
    $OutputDirectory = if ($OutputDirectory) { [string]::Concat($OutputDirectory, '\') } else { ".\" }
    $baseFileName = "groups_$currentDate"
    $extension = ".json"
    $counter = 0

    do {
        $fileName = if ($counter -eq 0) { "$baseFileName$extension" } else { [string]::Concat($baseFileName,"_$counter",$extension) }
        $filePath = [System.IO.Path]::Combine($OutputDirectory, $fileName)
        $counter++
    } while (Test-Path $filePath)

    try {
        $OutputObject = [PSCustomObject]@{
            TenantId = $TenantId
            Groups   = $GroupList
        }
        $OutputObject | ConvertTo-Json -Depth 5 | Out-File -FilePath $filePath -Encoding UTF8
        Write-Output "JSON data saved to $filePath"
    } catch {
        Write-Error "Failed to save JSON data to $filePath : $_"
    }
}

$DirectoryRoleAssignement = @()
$DirectoryRoleAssignement = Get-MgRoleManagementDirectoryRoleAssignment
$TenantId = (Get-MgOrganization).Id
#Pagination function
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
        [string]$GroupId
    )
    $roles = $directoryRoleAssignement | Where-Object {$_.PrincipalId -eq $group.Id} 
    $roles = $roles | Select-Object -Property RoleDefinitionId
    return $roles
}
function Get-LicenseSku {
    param (
        [string]$GroupId
    )

    $group = Get-MgGroup -GroupId $groupId -Property "AssignedLicenses"
    $assignedLicenses = $group | Select-Object -ExpandProperty AssignedLicenses
    $skuIds = $assignedLicenses | Select-Object -ExpandProperty SkuId
    return $skuIds
}

Write-Host "Collecting groups..."
$Groups = Get-AllPages -Command { Get-MgGroup -All:$true }
$GroupList = [System.Collections.Generic.List[PSObject]]::New()
Write-Host "Collecting groups details..."

foreach ($group in $Groups) {
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
        $GroupList.add([PSCustomObject]@{
            Name            = $group.DisplayName
            ObjectId        = $group.Id
            Properties      = $groupProperties
        })
    } catch {
        Write-Warning "Failed to process group '$($group.DisplayName)' (ID: $($group.Id)): $_"
        continue
    }
}

Export-Output
Disconnect-MgGraph > $null
