<#
    .DESCRIPTION
    This is script collects all autoforwarding and redirecting email rules from users' mailboxes.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$TenantDomain
)

if (-not (Get-Module ExchangeOnlineManagement)) {
    Import-Module ExchangeOnlineManagement -ErrorAction Stop
}
if (-not(Get-ConnectionInformation)){
    try {
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop -Verbose:$false -ShowProgress:$false 2>$null
    }
    catch {
        Write-Host "Missing connection to Exchange Online. Please check the connection andtry again." 
        Write-Host "Error: $($_.Exception.Message)"
        exit
    }
}
$Mailboxes = Get-ExoMailbox -ResultSize Unlimited 
Write-Host 'Collecting rules'
foreach ($mailbox in $Mailboxes) {
    Write-Host '.' -NoNewline
    $rules = Get-InboxRule -Mailbox $_.PrimarySmtpAddress
    foreach ($rule in $rules) {
        $externalTargets = @()
        $recipients = @()
        if ($rule.ForwardTo) {
            $recipients += $rule.ForwardTo
        }
        if ($rule.RedirectTo) {
            $recipients += $rule.RedirectTo
        }

        foreach ($recipient in $recipients) {
            $resolved = Get-Recipient -Identity $recipient.Identity
            if ($resolved.PrimarySmtpAddress -and
                $resolved.PrimarySmtpAddress -notlike "*@$TenantDomain") {
                $externalTargets += $resolved.PrimarySmtpAddress
            }
        }

        if ($externalTargets.Count -gt 0) {
            [PSCustomObject]@{
                Mailbox         = $_.PrimarySmtpAddress
                RuleName        = $rule.Name
                ExternalTargets = ($externalTargets -join ', ')
                Enabled         = $rule.Enabled
            }
        }
    }
}