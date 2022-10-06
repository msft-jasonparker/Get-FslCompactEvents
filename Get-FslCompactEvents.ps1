[CmdletBinding()]
Param (
    [Parameter(ValueFromPipeline=$true)]
    [string[]]$ComputerNames = $env:COMPUTERNAME,
    [System.Int32]$SearchHistoryInDays = 30,
    [ValidateSet("AllEvents","Metrics")]
    [System.String]$Output = "Metrics",
    [Switch]$ExportData
)
BEGIN {
    Write-Verbose ("FSLlogix VHD Disk Compaction Event Search | last {0} days | Display Option: {1} | Export Data: {2}" -f $timeToSearch,$DisplayOption,$ExportData)
    $startTime = (Get-Date).AddDays(-$SearchHistoryInDays)
    $fileTimestamp = (Get-Date -Format yyyyMMdd_HHmmss)
    [System.Collections.Generic.List[System.Object]]$allEvents = @()
    $countComputerNames = 0
}
PROCESS {
    Foreach ($ComputerName in $ComputerNames) {
        try {
            If (-NOT $ComputerName.Contains(".")) { $ComputerName = ([System.Net.Dns]::GetHostByName($ComputerName)).HostName }
            Write-Verbose ("Collecting Events from: {0}" -f $ComputerName)

            $diskCompactionEvents = Get-WinEvent -ComputerName $ComputerName -FilterHashtable @{
                StartTime       = $startTime
                ProviderName    = 'Microsoft-FSLogix-Apps'
            } -ErrorAction Stop | Where-Object { $_.ID -in 57, 58, 60, 61, 62 }

            If ($diskCompactionEvents.Count -gt 0) {
                Write-Verbose ("FOUND: {0} Events" -f $diskCompactionEvents.Count)
                $diskCompactionEvents | ForEach-Object { $allEvents.Add($_) }
            }
            Else { Write-Verbose ("FOUND: {0} Events" -f $diskCompactionEvents.Count) }
            $countComputerNames++
        }
        catch { Write-Host ("====>  FAILED: Unable to query Get-WinEvents for {0} ({1})" -f $ComputerName,$_.Exception.Message) -BackgroundColor Red -ForegroundColor White }
    }
}
END {
    $countLogs = ($allEvents | Select-Object LogName -Unique | Measure-Object).Count
    Write-Verbose ("Found {0} events from {1} EventLog(s) across {2} VM(s) since {3}" -f $allEvents.Count,$countLogs,$countComputerNames,$startTime)

    $compactionMetrics = $allEvents | Where-Object { $_.id -eq 57 } | Select-Object @{l="Timestamp";e={$_.TimeCreated}},
        @{l="ComputerName";e={$_.MachineName}},
        @{l="Path";e={$_.Properties[0].Value}},
        @{l="DiskCompaction";e={$_.Properties[1].Value}},
        @{l="TimeSpentInSec";e={[math]::round($_.Properties[7].Value / 1000,2)}},
        @{l="MaxSizeInGB";e={[math]::round($_.Properties[2].Value / 1024,2)}},
        @{l="MinSizeInGB";e={[math]::round($_.Properties[3].Value / 1024,2)}},
        @{l="InitialSizeInGB";e={[math]::round($_.Properties[4].Value / 1024,2)}},
        @{l="FinalSizeInGB";e={[math]::round($_.Properties[5].Value / 1024,2)}},
        @{l="SavedSpaceInGB";e={[math]::round($_.Properties[6].Value / 1024,2)}}
    
    If ($allEvents.Count -gt 0) {

        If ($ExportData) {
            Write-Host ("[CSV EXPORT]: {0}\fsl-compact-events-all-{1}.csv" -f $env:TEMP,$fileTimestamp) -ForegroundColor Green
            $allEvents | Select-Object TimeCreated,LogName,LevelDisplayName,ID,MachineName,Message | Export-Csv -Path ("{0}\fsl-compact-events-all-{1}.csv" -f $env:TEMP,$fileTimestamp) -NoTypeInformation
            Write-Host ("[CSV EXPORT]: {0}\fsl-compact-metrics-{1}.csv" -f $env:TEMP,$fileTimestamp) -ForegroundColor Green
            $compactionMetrics | Export-Csv -Path ("{0}\fsl-compact-metrics-{1}.csv" -f $env:TEMP,$fileTimestamp) -NoTypeInformation
        }

        Switch ($Output) {
            "AllEvents" { Return $allEvents | Select-Object TimeCreated,LogName,LevelDisplayName,ID,MachineName,Message }
            "Metrics" { Return $compactionMetrics }
        }
    }
    Else { Write-Warning ("No VHD Disk Compaction events were found") }
}
