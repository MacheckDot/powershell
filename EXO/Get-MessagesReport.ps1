<#
.SYNOPSIS
Retrieves Exchange Online message trace data and exports results to a CSV report.

.DESCRIPTION
This script queries message trace data using Get-MessageTraceV2 with support for
flexible filtering, automatic pagination, and date range chunking. It is designed
to efficiently handle large datasets by splitting queries into 10-day intervals
and aggregating results across multiple pages.

Filtering can be applied on sender, recipient, subject, message status, and IP
addresses. Results are normalized, sorted by received date, and exported to a
Unicode-encoded CSV file.

.PARAMETER ReportPeriod
Number of days to include in the report (1–90). Used when StartDate/EndDate are not fully specified.

.PARAMETER StartDate
Start date of the reporting range.

.PARAMETER EndDate
End date of the reporting range.

.PARAMETER Subject
Filters messages by subject content (substring match).

.PARAMETER SenderAddress
Filters messages by sender email address.

.PARAMETER RecipientAddress
Filters messages by recipient email address.

.PARAMETER Status
Filters messages by delivery status.

.PARAMETER SenderIP
Filters messages by source IP address.

.PARAMETER RecipientIP
Filters messages by destination IP address.

.PARAMETER ExportPath
Directory where the CSV report will be saved.

.PARAMETER FileName
Base name of the output file. Current date is appended automatically.

.OUTPUTS
CSV file containing all message trace data matching requirements.

.NOTES
- Requires Exchange Online PowerShell module
- Handles pagination using warning messages returned by Get-MessageTraceV2
- Uses 10-day query intervals to avoid API limitations
- Optimized for large result sets using in-memory list aggregation

Author: Maciej Pawiński
#>

param(
    [Parameter()]
    [ValidateRange(1, 90)]
    [Int16]$ReportPeriod = 30,

    [Parameter()]
    [string]$Subject,

    [Parameter()]
    [ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')]
    [string]$RecipientAddress,

    [Parameter()]
    [ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')]
    [string]$SenderAddress,

    [Parameter(ParameterSetName="Path")]
    [string]$ExportPath = '.\',

    [Parameter()]
    [string]$FileName = 'message_tracing_report_',

    [Parameter()]
    [datetime]$StartDate,

    [Parameter()]
    [datetime]$EndDate,

    [Parameter()]
    [ValidateSet('Delivered','Expanded','Failed','FilteredAsSpam','GettingStatus','Pending','Quarantined')]
    [string]$Status,

    [Parameter()]
    [ValidatePattern('^(((?!25?[6-9])[12]\d|[1-9])?\d\.?\b){4}$')]
    [string]$SenderIP,

    [Parameter()]
    [ValidatePattern('^(((?!25?[6-9])[12]\d|[1-9])?\d\.?\b){4}$')]
    [string]$RecipientIP
)


function Export-Output {
    param(
        [PSCustomObject]
        $output
    )
    [string]$currentDate = Get-Date -Format dd_MM_yyyy
    $OutputDirectory = if ($ExportPath ) { [string]::Concat($ExportPath , '\') } else { ".\" }
    $baseFileName = $FileName
    $extension = ".csv"
    $counter = 0

    do {
        $fileName = if ($counter -eq 0) {  [string]::Concat($baseFileName,"_",$currentDate,$extension) } else { [string]::Concat($baseFileName,"_",$currentDate,"_$counter",$extension) }
        $filePath = [System.IO.Path]::Combine($OutputDirectory, $fileName)
        $counter++
    } 
    while (Test-Path $filePath)

    try {
        $output | Export-Csv -Path $filePath -Encoding unicode -NoTypeInformation
        Write-Output "Report saved to $filePath"
    } 
    catch {
        Write-Error "Failed to save the report: $_"
    }
}

#Test connection to exchange
function Test-ExchangeConnection {
    $session = Get-ConnectionInformation
    if($session) {
        Write-Host "Connected to ExchangeOnline tenant $($session.TenantID) as $($session.UserPrincipalName)"
        
    }
    if ($session -eq "" -or $session.State -ne 'Connected') {
        Write-Host "Attempting to connect to Exchange Online..."
        try {
            $userPrincipalName =  Read-Host "Enter login name: "
            Connect-ExchangeOnline -UserPrincipalName $userPrincipalName -ShowBanner:$false
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

if(-not(Test-ExchangeConnection)){
    break
}

#Check for end or start date with a period scope, if nothing, use todays date
if ($StartDate -and -not($EndDate)) {
    $CurrentEndDate = $StartDate.AddDays($ReportPeriod)
}
elseif (-not($StartDate) -and $EndDate){
    $CurrentEndDate = $EndDate
    $StartDate = $EndDate.AddDays(-$ReportPeriod)
}
elseif ($StartDate -and $EndDate) {
    $CurrentEndDate = $EndDate
}
else {
    $CurrentEndDate = Get-Date
    $StartDate = $CurrentEndDate.AddDays(-$ReportPeriod)
}

$AllMessages = [System.Collections.Generic.List[PSObject]]::new()

while ($CurrentEndDate -gt $StartDate) {
    $ChunkStartDate = $CurrentEndDate.AddDays(-10)
    if ($ChunkStartDate -lt $StartDate) {
        $ChunkStartDate = $StartDate
    }

    Write-Host "Fetching messages from $($ChunkStartDate.ToShortDateString()) to $($CurrentEndDate.ToShortDateString())..."

    $params = @{
        StartDate       = $ChunkStartDate
        EndDate         = $CurrentEndDate
        ResultSize      = 5000
        Verbose         = $false
        WarningVariable = "MoreResultsAvailable"
    }
    if ($RecipientAddress) { $params.RecipientAddress = $RecipientAddress }
    if ($SenderAddress) { $params.SenderAddress = $SenderAddress }
    if ($Status) { $params.Status = $Status}
    if ($SenderIP) {$params.FromIP = $SenderIP}
    if ($RecipientIP) {$params.ToIP = $RecipientIP}

    $cMessages = Get-MessageTraceV2 @params 3>$null
    
    # Process results
    if ($cMessages) {
        $selected = if ($Subject) { 
            $cMessages | Where-Object { $_.Subject -match [regex]::Escape($Subject) } | Select-Object Received, SenderAddress, RecipientAddress, Size, Status, Subject, MessageId, MessageTraceId, FromIP, ToIP #$_.Contains() is the fastest filtering
        }
        else { 
            $cMessages | Select-Object Received, SenderAddress, RecipientAddress, Size, Status, Subject, MessageId, MessageTraceId, FromIP, ToIP
        }
        
       
        foreach ($item in $selected) {
            [void]$AllMessages.Add($item)
        }
    }

    #Handle Pagination
    while ($MoreResultsAvailable) {
        Write-Host "." -NoNewline
        $nextPageCommand = ($MoreResultsAvailable -join "") -replace "There are more results, use the following command to get more. ", ""
        
        if ($nextPageCommand -match "Get-MessageTraceV2") {
            $scriptBlock = [ScriptBlock]::Create($nextPageCommand)
            $cMessages = Invoke-Command -ScriptBlock $scriptBlock -WarningVariable MoreResultsAvailable -Verbose:$false 3>$null
            
            if ($cMessages) {
                $selected = if ($Subject) { 
                    $cMessages | Where-Object { $_.Subject -match [regex]::Escape($Subject)  } | Select-Object Received, SenderAddress, RecipientAddress, Size, Status, Subject, MessageId, MessageTraceId, FromIP, ToIP 
                }
                else { 
                    $cMessages | Select-Object Received, SenderAddress, RecipientAddress, Size, Status, Subject, MessageId, MessageTraceId, FromIP, ToIP
                }
                
                foreach ($item in $selected) {
                    [void]$AllMessages.Add($item)
                }
            }
        }
        else {
            break
        }
    }

    # Go to the next 10 day chunk
    $CurrentEndDate = $ChunkStartDate
}

if ($AllMessages.Count -eq 0) {
    Write-Error "No messages found for the specified criteria. Please check your permissions or update the parameters."
    return
}

$SortedAllMessages = $AllMessages | Sort-Object  Received

Export-Output -output $SortedAllMessages
Write-Host "Report exported to $filePath"
