Import-Module Microsoft.Online.SharePoint.PowerShell
$siteUrl = RRead-Host "Enter SPO Url:"

Connect-SPOService -Url $siteUrl -ModernAuth $true -AuthenticationUrl https://login.microsoftonline.com/organizations


function Get-FilesAndFolders {
    param (
        [string]$folderUrl
    )

    $items = Get-PnPListItem -List "Documents" -FolderServerRelativeUrl $folderUrl

    foreach ($item in $items) {
        if ($item.FileSystemObjectType -eq "File") {
            Write-Host "File: $($item.FieldValues['FileLeafRef'])"
        } elseif ($item.FileSystemObjectType -eq "Folder") {
            $folderName = $item.FieldValues['FileLeafRef']
            Write-Host "Folder: $folderName"
            List-FilesAndFolders -folderUrl "$folderUrl/$folderName"
        }
    }
}

$rootFolderUrl = "/sites/yoursite/Shared Documents"
Get-FilesAndFolders -folderUrl $rootFolderUrl

Disconnect-SPOService