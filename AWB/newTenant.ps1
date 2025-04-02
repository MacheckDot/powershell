<#
.SYNOPSIS
    A script that creates simple structure in Entra ID 

.DESCRIPTION
    The scripts creates user accounts, security groups, assign all available licenses to users, assign users to groups and managers to users. 

.PARAMETER yourName
    Your name, to create your account.

.PARAMETER yourSurname
     Your surname, to create your account.

.PARAMETER yourUPN
     Your UPN suffix (without the domain).

.PARAMETER domain
     Your domain.

.PARAMETER defaultPassword
    This is default password for all new users.

.EXAMPLE
    .\\newTenant.ps1 -yourName "Maciej" -yourSurname "Pawiński" -yourUPN "maciej.pawinski" -domain "HM0123.onmicrosoft.com" -defaultPassword "Password123"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$yourName,

    [Parameter(Mandatory=$true)]
    [string]$yourSurname,

    [Parameter(Mandatory=$true)]
    [string]$yourUPN,

    [Parameter(Mandatory=$true)]
    [string]$domain,

    [Parameter(Mandatory=$true)]
    [securestring]$defaultPassword
)

$scope = @('User.ReadWrite.All', 'Group.ReadWrite.All')

# Connect to MS Graph
if (Get-MgContext -ErrorAction SilentlyContinue) {
    Write-Host 'You are already connected to Microsoft Graph.'
} else {
    Connect-MgGraph -Scopes $scope -NoWelcome
    Write-Host 'You have connected to Microsoft Graph.'
}

# Retrieve licenses
$licenses = Get-MgSubscribedSku | Select-Object -ExpandProperty SkuId | ForEach-Object { @{SkuId = $_} }

# User list (hash array)
$users = @(
    @{FirstName = 'Anna'; LastName = 'Andrusik'; UPN = "anna.andrusik@$domain"; Department = 'HR'},
    @{FirstName = 'Maciej'; LastName = 'Biernat'; UPN = "maciej.biernat@$domain"; Department = 'MGMT'},
    @{FirstName = 'Adrian'; LastName = 'Chodakowski'; UPN = "adrian.chodakowski@$domain"; Department = 'ACC'},
    @{FirstName = 'Barbara'; LastName = 'Galińska'; UPN = "barbara.galinska@$domain"; Department = 'MGMT'},
    @{FirstName = 'Marta'; LastName = 'Kaczmarczyk'; UPN = "marta.kaczmarczyk@$domain"; Department = 'LOG'},
    @{FirstName = 'Jan'; LastName = 'Kowalski'; UPN = "jan.kowalski@$domain"; Department = 'IT'},
    @{FirstName = 'Aleksandra'; LastName = 'Majkowska'; UPN = "aleksandra.majkowska@$domain"; Department = 'ACC'},
    @{FirstName = 'Rafał'; LastName = 'Polakowski'; UPN = "rafal.polakowski@$domain"; Department = 'LOG'},
    @{FirstName = 'Magdalena'; LastName = 'Rawecka'; UPN = "magdalena.rawecka@$domain"; Department = 'HR'},
    @{FirstName = 'Joanna'; LastName = 'Wiśniewska'; UPN = "joanna.wisniewska@$domain"; Department = 'IT'},
    @{FirstName = $yourName; LastName = $yourSurname; UPN = [string]::Join("",$yourUPN,'@',$domain); Department = "IT"}
)

# Groups to create
$groups = @('IT', 'ACC', 'HR', 'LOG', 'MGMT')

# Create groups
$groupIds = @{}

foreach ($group in $groups) {
    if (-not (Get-MgGroup | Where-Object { $_.DisplayName -eq $group })) {
        New-MgGroup -DisplayName $group -MailEnabled:$False -MailNickName $group -SecurityEnabled
    }
    $groupIds[$group] = (Get-MgGroup | Where-Object { $_.DisplayName -eq $group }).Id
}

# Create or update users
for ($i = 0; $i -lt $users.Count; $i++) {
    $user = $users[$i]

    # Check if the user already exists
    $existingUser = Get-MgUser | Where-Object { $_.UserPrincipalName -eq $user.UPN }

    if ($existingUser) {
        $users[$i].Id = $existingUser.Id
        Write-Host "User $($user.FirstName) $($user.LastName) already exists with ID: $($user.Id)."
        $users[$i].DisplayName = "$($user.FirstName) $($user.LastName)"
    } else {
        $userDisplayName = "$($user.FirstName) $($user.LastName)"
        $userMailNickname = ($user.UPN.Split('@')[0]).Split('.')[0].Substring(0, 1) + ($user.UPN.Split('@')[0]).Split('.')[1]
        $users[$i].DisplayName = $userDisplayName

        $newUser = New-MgUser -AccountEnabled -DisplayName $userDisplayName -UserPrincipalName $user.UPN -Mail $user.UPN `
            -MailNickname $userMailNickname -PasswordProfile @{ Password = "$defaultPassword"; ForceChangePasswordNextSignIn = $true } `
            -UsageLocation 'PL' -Department $user.Department
        
        $users[$i].Id = $newUser.Id
        Write-Host "User $userDisplayName has been created with ID: $($users[$i].Id)."
    }

    # Assign licenses to the user
    try {
        Set-MgUserLicense -UserId $users[$i].Id -AddLicenses $licenses -RemoveLicenses @()
        Write-Host "Licenses successfully assigned to $($user.FirstName) $($user.LastName)."
    } catch {
        Write-Host "Failed to assign licenses to $($user.FirstName) $($user.LastName): $($_.Exception.Message)"
    }
}

# Add users to groups
foreach ($user in $users) {
    $userUPN = $user.UPN
    $odataID = "https://graph.microsoft.com/v1.0/users/$userUPN"

    try {
        New-MgGroupMemberByRef -GroupId $groupIds[$user.Department] -OdataId $odataID
        Write-Host "User $($user.FirstName) $($user.LastName) added to group $($user.Department)."
    } catch {
        Write-Host "Failed to add $($user.FirstName) $($user.LastName) to group $($user.Department): $($_.Exception.Message)"
    }
}

# Add managers to users
for ($i = 0; $i -lt $users.Count; $i++) {
    $currentUser = $users[$i]

    # Managers list
    switch ($currentUser.DisplayName) {
        'Anna Andrusik' { $managerDisplayName = 'Barbara Galińska' }
        'Adrian Chodakowski' { $managerDisplayName = 'Barbara Galińska' }
        'Magdalena Rawecka' { $managerDisplayName = 'Anna Andrusik' }
        'Aleksandra Majkowska' { $managerDisplayName = 'Adrian Chodakowski' }
        "$yourName $yourSurname" { $managerDisplayName = 'Maciej Biernat' }
        'Jan Kowalski' { $managerDisplayName = "$yourName $yourSurname" }
        'Joanna Wiśniewska' { $managerDisplayName = "$yourName $yourSurname" }
        'Marta Kaczmarczyk' { $managerDisplayName = 'Maciej Biernat' }
        'Rafał Polakowski' { $managerDisplayName = 'Marta Kaczmarczyk' }
        default { $managerDisplayName = '' } 
    }

    # Find the manager object in the users list
    $manager = $users | Where-Object { $_.DisplayName -eq $managerDisplayName }

    if ($manager) {
        $managerId = $manager.Id        
        $newManager = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/users/$managerId"
        }

        Set-MgUserManagerByRef -UserId $currentUser.Id -BodyParameter $newManager
    } else {
        Write-Host "Manager not found for User: $($currentUser.DisplayName), skipping..."
    }
}
