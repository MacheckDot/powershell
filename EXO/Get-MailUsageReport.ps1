[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet(7,30,90)]
    [Int16]$ReportPeriod,
    [ValidateSet(1,2)] 
    [Int16]$ConnectionType = 2, # 1 for interactive login, 2 for non-interactive session
    [Guid]$AppId
)

#region check modules
#Export to XLSX + ExchangeManagemntModule
#endregion
#region connect to EXO SP or manual
if (not(Get-ConnectionInformation)){
    switch ($ConnectionType) {
        1 {Connect-ExchangeOnline -ShowBanner:$false }
        2 {Connect-ExchangeOnline -AppId $AppId -CertificateThumbprint $CertificateThumbprint -Organization $Organization }
    }
}


#endregion


function Get-Messages {
    #this is to handle max period of 10 days, while the report's maximum period is 90 days
    $days = -$ReportPeriod
    $startDate = $(Get-Date).AddDays($days)
    $endDate = Get-Date
    if (($endDate-$startDate).Days -gt 10){
        $tempDate = $endDate.AddDays(-10)

        while ($tempDate -ge $startDate) {
            #####
            $messages = $null
            $cMessages = Get-MessageTraceV2 -ResultSize 5000 -StartDate $startDate -EndDate $endDate -WarningVariable MoreResultsAvailable -Verbose:$false 3>$null
            $messages += $cMessages | Select-Object Received,SenderAddress,RecipientAddress,Size,Status

            #If more results are available, as indicated by the presence of the WarningVariable, we need to loop until we get all results
            if ($MoreResultsAvailable) {
                do {
                    #As we don't have a clue how many pages we will get, proper progress indicator is not feasible.
                    Write-Host "." -NoNewline

                    #Handling this via Warning output is beyong annoying...
                    $nextPage = ($MoreResultsAvailable -join "").TrimStart("There are more results, use the following command to get more. ")
                    $scriptBlock = [ScriptBlock]::Create($nextPage)
                    $cMessages = Invoke-Command -ScriptBlock $scriptBlock -WarningVariable MoreResultsAvailable -Verbose:$false 3>$null #MUST PASS WarningVariable HERE OR IT WILL NOT WORK
                    $messages += $cMessages | Select-Object Received,SenderAddress,RecipientAddress,Size,Status
                    }
                until ($MoreResultsAvailable.Count -eq 0)
            }
            if ($messages.Count -eq 0) {
                Write-Error "No messages found for the specified date range. Please check your permissions or update the date range above."
                return
            }

            #####
            $tempDate = $tempDate.AddDays(-10)
        }

    }
    
}
#function to craete user object with all attributes 

Get-Messages
$messages
#export to xlsx