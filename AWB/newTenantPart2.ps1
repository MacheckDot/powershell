<#
.SYNOPSIS
    A script that update groups to dynamic ones and let user to chek for exisiting manager of Entra ID user

.DESCRIPTION
    This script change all static groups in tenant to dynamic. Then let user to check for existing manager of Entra ID user.  

.EXAMPLE
    .\\newTenantPart2.ps1
    
    Runs the script with the specified input and output files.
#>

$scope = @('User.ReadWrite.All', 'Group.ReadWrite.All')

# Connect to MS Graph
if (Get-MgContext -ErrorAction SilentlyContinue) {
    Write-Host 'You are already connected to Microsoft Graph.'
} else {
    Connect-MgGraph -Scopes $scope -NoWelcome
    Write-Host 'You have connected to Microsoft Graph.'
}

# Update all security groups to dyamic groups
$allGroups = Get-MgGroup -All

foreach ($group in $allGroups) {
    $groupName = [string]::Join("",'"',$group.DisplayName.Trim(),'"')
    $membershipRule = "(user.accountEnabled -eq true) and (user.department -eq $groupName )"

    Update-MgGroup -GroupId $group.Id -BodyParameter @{
        MembershipRule = $membershipRule
        MembershipRuleProcessingState = "On"
        GroupTypes = @("DynamicMembership")
    }
}

# Prompt user to enter a user's name to check for the manager
do {
    $searchName = Read-Host -Prompt "Enter the user to check their manager (leave blank to exit)"
    $manager = $NULL

    if (![string]::IsNullOrWhiteSpace($searchName)) {
        $foundUser = Get-MgUser |  Where-Object { $_.DisplayName -eq $searchName }
        
        if ($foundUser) {
            if ($foundUser.Id) {
                try {
                    # Retrieve the manager
                    $manager =  Get-MgUser -UserId $(Get-MgUserManager -UserId $foundUser.Id).Id

                    if ($manager) {
                        Write-Host "The manager of $($foundUser.DisplayName) is $($manager.DisplayName)."
                    } else {
                        Write-Host "No manager is assigned to $($foundUser.DisplayName)."
                    }
                } catch {
                    Write-Host "Error retrieving manager for $($foundUser.DisplayName): $($_.Exception.Message)"
                }
            } else {
                Write-Host "$($foundUser.DisplayName) does not have a valid ID assigned."
            }
        } else {
            Write-Host "User '$searchName' not found in the tenant."
        }
    }

} while (![string]::IsNullOrWhiteSpace($searchName))
