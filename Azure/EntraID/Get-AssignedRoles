<#
.SYNOPSIS
    This script collects inforamtion about all actively assigned roles in the Tenant and groups them by asigned user.
    
    Author: Maciej Pawiński
#>

param (
    [string]$directoryPath
)

try {
    # Check if already connected
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "RoleManagement.Read.Directory", "User.Read.All" -NoWelcome
    }
} catch {
    Write-Error "Failed to connect to Microsoft Graph: $_"
    exit
}

#must have, as it's the only way to get enabled and external accounts with Graph
$enabledAccounts = @(Get-MgUser -Filter "accountEnabled eq true" -All | Select-Object Id)
$externalAccounts = @(Get-MgUser -Filter "Creationtype eq 'Invitation'" -All | Select-Object -Property Id)

$roles = Get-MgRoleManagementDirectoryRoleDefinition
$roleAssignmentsByUser = @{}

foreach ($role in $roles) {
    $assignedUsers = Get-MgRoleManagementDirectoryRoleAssignment -Filter "RoleDefinitionId eq '$($role.Id)'"

    if ($assignedUsers.Count -ge 1) {
        
        foreach ($user in $assignedUsers) {
            if ($user.PrincipalId) {
            try {
                $userDetails = Get-MgUser -UserId $user.PrincipalId -ErrorAction Stop
            } catch {
                Write-Warning "User with PrincipalId $($user.PrincipalId) not found."
                continue
                }
            }

            $accountType = if ($externalAccounts.Id -contains $user.PrincipalId) { "External" } else { "Internal" }

            $accountStatus = if ($enabledAccounts.Id -contains $user.PrincipalId) { "Active" } else { "Inactive" }

            if ($userDetails -and $userDetails.Id -and (-not $roleAssignmentsByUser.ContainsKey($userDetails.Id))) {
                $roleAssignmentsByUser[$userDetails.Id] = @{
                    
                    userId         = $userDetails.Id
                    DisplayName    = $userDetails.DisplayName
                    AccountType    = $accountType
                    AccountStatus  = $accountStatus
                    Roles          = @()
                }
            }

            # Append role info to user object
            if ($userDetails -and $userDetails.Id) {
                $roleAssignmentsByUser[$userDetails.Id].Roles += @{
                    roleName = $role.DisplayName
                    roleId   = $role.Id
                }
            }
        }
    }
}

$today = (Get-Date).ToString("dd_MM_yyyy")


$directoryPath = if ($directoryPath) { [string]::Concat($directoryPath, '\') } else { ".\" }
$baseFileName = "assigned_roles_$today"
$extension = ".json"
$counter = 0

do {
    $fileName = if ($counter -eq 0) { "$baseFileName$extension" } else { [string]::Concat($baseFileName,"_$counter",$extension) }
    $filePath = [System.IO.Path]::Combine($directoryPath, $fileName)
    $counter++
} while (Test-Path $filePath)

try {
    $roleAssignmentsByUser  | ConvertTo-Json -Depth 3 | Out-File -FilePath $filePath -Encoding UTF8
    Write-Output "JSON data saved to $filePath"
} catch {
    Write-Error "Failed to save JSON data to $filePath : $_"
}
