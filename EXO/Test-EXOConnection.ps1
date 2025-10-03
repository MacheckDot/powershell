function Test-ExchangeConnection {
    $session = Get-ConnectionInformation
    $session
    if ($session -eq "" -or $session.State -ne 'Connected') {
        Write-Host "Attempting to connect to Exchange Online..."
        try {
            $UserPrincipalName =  Read-Host "Enter login name: "
            Connect-ExchangeOnline -UserPrincipalName $UserPrincipalName -ShowBanner:$false
            Write-Host "Connected to Exchange Online"
            return 1
        } catch {
            Write-Error "Failed to connect to Exchange Online: $_"
            return 0
        }
    }
    else {
        return 1
    }
}
Test-ExchangeConnection
