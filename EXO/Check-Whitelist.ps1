param (
    [string]$distributionList,
    [string]$senderDomain
)

$date = (Get-Date -Format "MM_dd_yyyy").ToString()
$fileName = "whitelist.csv"
$outputName = [string]::Join("_",$distributionList,$senderDomain,$date,$fileName)
#$outputPath = [string]::Join("",".\",$outputName.Substring(0,$outputName.Length-1))
$users = @()
$users = Get-DistributionGroupMember -Identity $distributionList | Select-Object -ExpandProperty PrimarySmtpAddress
#$users = Get-Mailbox | Where-Object {$_.Office -like 'PL - '} | Select-Object -ExpandProperty PrimarySmtpAddress
$results = @()

foreach ($user in $users) {
    $junkEmailConfig = Get-MailboxJunkEmailConfiguration -Identity $user | Select-Object -ExpandProperty TrustedSendersAndDomains

    $matchingSenders = $junkEmailConfig | findstr $senderDomain

    $result = [PSCustomObject]@{
        User                = $user
        MatchingSenders     = $matchingSenders -join ", "
    }

    $results += $result
}

$results | Export-Csv -Path ".\$outputName" -NoTypeInformation -Encoding UTF8
