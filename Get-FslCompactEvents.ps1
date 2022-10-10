<#
.SYNOPSIS
    Collects FSLogix VHD Disk Compaction event logs.
.DESCRIPTION
    This script takes a list of computer names and will attempt to collect the FSLogix VHD Disk Compaction event logs from those computers. The script will return the measured metrics from the disk compaction events and will optionally return all events related to disk compaction. Use cmdlets like Export-Csv or Out-File to save the results.
.NOTES
    The script will run with no input parameters and will collect information for the local computer over the last 30 days.
.EXAMPLE
    Get-FslCompactEvents.ps1
    Will collect logs and return the disk compact metircs from the last 30 days on the local computer.
.EXAMPLE
    Get-FslCompactEvents.ps1 -ComputerNames "Computer1","Computer2" | Export-Csv -Path $ENV:TEMP\fsl_compact_metrics.csv -NoTypeInformation
    Will collect logs from Computer1 and Computer2 from the last 30 days and save the data to a CSV file.
.EXAMPLE
    "Computer1","Computer2" | Get-FslCompactEvents.ps1 -Output AllEvents -Verbose
    Takes the computer names from the pipeline, collects the ALL disk compaction events from the last 30 days and provides verbose output.
#>
[CmdletBinding()]
Param (
    # List of ComputerName(s) to collect event log data from (e.g., "Computer1", "Computer2"). Can be piped to the script or listed as part of the -ComputerNames parameter. Defaults to the local computer.
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,HelpMessage="Type the list of computers to collect events from ('Computer1','Computer2').")]
    [System.String[]]$ComputerNames = $env:COMPUTERNAME,

    # The number of days to search in the event logs for the FSLogix compaction events. Defaults to 30 days.
    [Parameter(HelpMessage="Type the number of days to search for FSLogix compaction events.")]
    [System.Int32]$SearchHistoryInDays = 30,

    # The type of data to return. Default value is 'Metrics', but will accept 'AllEvents' which displays all compaction events. The parameter ONLY ACCEPTS one (1) of two (2) values: AllEvents or Metrics.
    [Parameter(HelpMessage="Type 'Metrics' or 'AllEvents' for the type of data to return.")]
    [ValidateSet("AllEvents","Metrics")]
    [System.String]$Output = "Metrics"
)
BEGIN {
    Write-Verbose ("FSLlogix VHD Disk Compaction Event Search | last {0} days | Output: {1}" -f $SearchHistoryInDays,$Output)
    $startTime = (Get-Date).AddDays(-$SearchHistoryInDays)
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
        catch { Write-Error ("====>  FAILED: Unable to query Get-WinEvents for {0} ({1})" -f $ComputerName,$_.Exception.Message) }
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

        Switch ($Output) {
            "AllEvents" { Return $allEvents | Select-Object TimeCreated,LogName,LevelDisplayName,ID,MachineName,Message }
            "Metrics" { Return $compactionMetrics }
        }
    }
    Else { Write-Warning ("No VHD Disk Compaction events were found") }
}
