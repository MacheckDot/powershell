$ipRange = @()
$portRange = @()

$results = @()

foreach ($ip in $ipRange) {
    foreach ($port in $portRange) {
        $testResult = Test-NetConnection $ip -Port $port | Select-Object ComputerName, RemotePort, TcpTestSucceeded
        $results += $testResult
        }
    }

$results | Export-Csv -Path .\output.csv -NoTypeInformation -Encoding UTF8
