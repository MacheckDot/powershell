param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 90)]
    [Int16]$ReportPeriod,

    [Parameter()]
    [string]$Subject,

    [Parameter()]
    [ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')]
    [string]$RecipientAddress,

    [Parameter()]
    [ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')]
    [string]$SenderAddress,

    [Parameter(ParameterSetName="Path")]
    [System.IO.DirectoryInfo]$ExportPath = '.\',

    [Parameter()]
    [string]$FileName = 'message_tracing_report_',

    [Parameter()]
    [ValidatePattern('^(0\d{1}|1[0-2])+\/+(0[1-9]|[12][0-9]|3[0-1])+\/+(2\d{3}))$')]
    [string]$StartDate,

    [Parameter()]
    [ValidatePattern('^(0\d{1}|1[0-2])+\/+(0[1-9]|[12][0-9]|3[0-1])+\/+(2\d{3}))$')]
    [string]$EndDate
)

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

    $cMessages = Get-MessageTraceV2 @params 3>$null
    
    # Process results
    if ($cMessages) {
        $selected = if ($Subject) { 
            $cMessages | Where-Object { $_.Subject -match [regex]::Escape($Subject) } | Select-Object Received, SenderAddress, RecipientAddress, Size, Status, Subject, MessageId
        }
        else { 
            $cMessages | Select-Object Received, SenderAddress, RecipientAddress, Size, Status, Subject, MessageId
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
                    $cMessages | Where-Object { $_.Subject -match [regex]::Escape($Subject) } | Select-Object Received, SenderAddress, RecipientAddress, Size, Status, Subject, MessageId
                }
                else { 
                    $cMessages | Select-Object Received, SenderAddress, RecipientAddress, Size, Status, Subject, MessageId
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

$date = Get-Date -Format 'dd_MM_yyyy'
$FileName = [string]::Join('',$FileName,$date,'.csv')
$FinalPath = Join-Path -Path $ExportPath -ChildPath $FileName
$AllMessages | Export-Csv -Path $FinalPath -Encoding utf8 -NoTypeInformation
Write-Host "\nReport exported to $FinalPath"
