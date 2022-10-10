# Get-FslCompactEvents

This script is an optional tool which enables IT administrators to collect the FSLogix VHD Disk Compaction events from a single system or a collection of computers, over a period of days. IT administrators with computers in Azure or Azure Virtual Desktop should leverage the [Log Analytics queries](https://learn.microsoft.com/fslogix/reference-vhd-disk-compaction#azure-log-analytics-queries) after adding the FSLogix event logs to their agent configurations.

More information can be found on the offical Microsoft Learn site for the [VHD Disk Compaction](https://learn.microsoft.com/fslogix/concepts-vhd-disk-compaction) page.

## Simple PowerShell Snippet Version

```powershell
# Set startTime to number of days to search the event logs
$startTime = (Get-Date).AddDays(-30)

# Query Event Log using Get-WinEvent filtered to the VHD Disk Compaction metric events
$diskCompactionEvents = Get-WinEvent -FilterHashtable @{
    StartTime       = $startTime
    ProviderName    = 'Microsoft-FSLogix-Apps/Operational'
    EventID         = 57
}

# Format event properties
$compactionMetrics = $diskCompactionEvents | Select-Object `
    @{l="Timestamp";e={$_.TimeCreated}},`
    @{l="ComputerName";e={$_.MachineName}},`
    @{l="Path";e={$_.Properties[0].Value}},`
    @{l="WasCompacted";e={$_.Properties[1].Value}},`
    @{l="TimeSpent(sec)";e={[math]::round($_.Properties[7].Value / 1000,2)}},`
    @{l="MaxSize(GB)";e={[math]::round($_.Properties[2].Value / 1024,2)}},`
    @{l="MinSize(GB)";e={[math]::round($_.Properties[3].Value / 1024,2)}},`
    @{l="InitialSize(GB)";e={[math]::round($_.Properties[4].Value / 1024,2)}},`
    @{l="FinalSize(GB)";e={[math]::round($_.Properties[5].Value / 1024,2)}},`
    @{l="SavedSpace(GB)";e={[math]::round($_.Properties[6].Value / 1024,2)}}

# Display metrics in Out-GridView
$compactionMetrics | Out-GridView
```

## Script Overview

Get-FslCompactEvents.ps1 script overview.

### SYNOPSIS

Collects FSLogix VHD Disk Compaction event logs.

### DESCRIPTION

This script takes a list of computer names and will attempt to collect the FSLogix VHD Disk Compaction event logs from those computers. The script will return the measured metrics from the disk compaction events and will optionally return all events related to disk compaction. Use cmdlets like Export-Csv or Out-File to save the results.

### NOTES

The script will run with no input parameters and will collect information for the local computer over the last 30 days.

### EXAMPLE 1

```powershell
C:\MyScripts> .\Get-FslCompactEvents.ps1
```
Will collect logs and return the disk compact metircs from the last 30 days on the local computer.
    
### EXAMPLE 2

```powershell
C:\MyScripts> .\Get-FslCompactEvents.ps1 -ComputerNames "Computer1","Computer2" | Export-Csv -Path $ENV:TEMP\fsl_compact_metrics.csv -NoTypeInformation
```
Will collect logs from Computer1 and Computer2 from the last 30 days and save the data to a CSV file.
    
### EXAMPLE 3

```powershell
C:\MyScripts>"Computer1","Computer2" | .\Get-FslCompactEvents.ps1 -Output AllEvents -Verbose
```

Takes the computer names from the pipeline, collects the ALL disk compaction events from the last 30 days and provides verbose output.

