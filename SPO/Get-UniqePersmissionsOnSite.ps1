# Load SharePoint Online Management Shell module
Import-Module Microsoft.Online.SharePoint.PowerShell

# Connect to SharePoint Online
$siteUrl = "https://pernodricard-admin.sharepoint.com/"

Connect-SPOService -Url $siteUrl

# Function to list files and folders recursively
function Get-FilesAndFolders {
    param (
        [string]$folderUrl
    )

    # Get the items in the folder
    $items = Get-PnPListItem -List "Documents" -FolderServerRelativeUrl $folderUrl

    foreach ($item in $items) {
        if ($item.FileSystemObjectType -eq "File") {
            # It's a file
            Write-Host "File: $($item.FieldValues['FileLeafRef'])"
        } elseif ($item.FileSystemObjectType -eq "Folder") {
            # It's a folder
            $folderName = $item.FieldValues['FileLeafRef']
            Write-Host "Folder: $folderName"
            # Call the function recursively for the subfolder
            List-FilesAndFolders -folderUrl "$folderUrl/$folderName"
        }
    }
}

# Specify the root folder (change to your desired folder)
$rootFolderUrl = "/sites/yoursite/Shared Documents"
Get-FilesAndFolders -folderUrl $rootFolderUrl

# Disconnect from SharePoint Online
Disconnect-SPOService