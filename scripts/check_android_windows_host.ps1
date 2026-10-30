param(
    [Parameter(Mandatory = $true)]
    [string]$ReportDirectory
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
New-Item -ItemType Directory -Path $ReportDirectory -Force | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
$report = [ordered]@{
    schemaVersion = 1
    observedAt = (Get-Date).ToUniversalTime().ToString('o')
    purpose = 'Read-only Windows Android host diagnosis; no guest runtime validation'
    runId = $env:GITHUB_RUN_ID
    runAttempt = $env:GITHUB_RUN_ATTEMPT
    runner = $env:RUNNER_NAME
    processArchitecture = $env:PROCESSOR_ARCHITECTURE
    wow64Architecture = $env:PROCESSOR_ARCHITEW6432
    sessionId = (Get-Process -Id $PID).SessionId
}

# Runner labels and an x64 Python process do not establish the native OS ISA.
# IsWow64Process2 reports both identities even under Windows ARM emulation.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ZstandardWindowsArchitecture {
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool IsWow64Process2(
        IntPtr process, out ushort processMachine, out ushort nativeMachine);
}
'@
[UInt16]$processMachine = 0
[UInt16]$nativeMachine = 0
if (-not [ZstandardWindowsArchitecture]::IsWow64Process2(
        [IntPtr](-1), [ref]$processMachine, [ref]$nativeMachine)) {
    throw ('IsWow64Process2 failed: {0}' -f [Runtime.InteropServices.Marshal]::GetLastWin32Error())
}
$machineNames = @{0 = 'native'; 0x014c = 'x86'; 0x8664 = 'AMD64'; 0xaa64 = 'ARM64'}
$report.nativeArchitecture = [ordered]@{
    processMachine = ('0x{0:x4}' -f $processMachine)
    processMachineName = $machineNames[[int]$processMachine]
    nativeMachine = ('0x{0:x4}' -f $nativeMachine)
    nativeMachineName = $machineNames[[int]$nativeMachine]
}
[IO.File]::WriteAllText((Join-Path $ReportDirectory 'windows-android-host.json'),
    ($report | ConvertTo-Json -Depth 12), $utf8)
$report.operatingSystem = Get-CimInstance Win32_OperatingSystem |
    Select-Object Caption, Version, BuildNumber, OSArchitecture,
        TotalVisibleMemorySize, FreePhysicalMemory,
        TotalVirtualMemorySize, FreeVirtualMemory
$report.computer = Get-CimInstance Win32_ComputerSystem |
    Select-Object Manufacturer, Model, HypervisorPresent, TotalPhysicalMemory
$report.processors = @(Get-CimInstance Win32_Processor |
    Select-Object Name, Manufacturer, Architecture, AddressWidth,
        NumberOfCores, NumberOfLogicalProcessors,
        VirtualizationFirmwareEnabled, SecondLevelAddressTranslationExtensions,
        VMMonitorModeExtensions)
$report.disks = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' |
    Select-Object DeviceID, FreeSpace, Size)

try {
    $report.hypervisorFeature = Get-CimInstance Win32_OptionalFeature |
        Where-Object { $_.Name -eq 'HypervisorPlatform' } |
        Select-Object Name, InstallState
} catch {
    $report.hypervisorFeatureQueryError = $_.Exception.Message
}

# Restrict crash evidence to the two owned SDKs from the recorded experiments.
# Do not collect memory dumps, unrelated application events or user environment.
$ownedSdkMarkers = @(
    'zstandard-android-sdk-40863711078-1',
    'zstandard-android-sdk-40867022157-1'
)
$crashes = @()
try {
    $events = @(Get-WinEvent -FilterHashtable @{
        LogName = 'Application'
        Id = @(1000, 1001, 1002)
        StartTime = (Get-Date).AddDays(-2)
    } -MaxEvents 1000 -ErrorAction SilentlyContinue)
    foreach ($eventRecord in $events) {
        $message = $eventRecord.Message
        $owned = $false
        foreach ($marker in $ownedSdkMarkers) {
            if ($message -and $message.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $owned = $true
            }
        }
        if (-not $owned) { continue }
        [xml]$xml = $eventRecord.ToXml()
        $fields = [ordered]@{}
        foreach ($item in $xml.Event.EventData.Data) {
            if ($item.Name) { $fields[[string]$item.Name] = [string]$item.'#text' }
        }
        $crashes += [ordered]@{
            timeCreated = $eventRecord.TimeCreated.ToUniversalTime().ToString('o')
            id = $eventRecord.Id
            provider = $eventRecord.ProviderName
            data = $fields
        }
    }
} catch {
    $report.ownedCrashQueryError = $_.Exception.Message
}
$report.ownedCrashEvents = $crashes
$report.hostSettingsChanged = $false
$report.runtimeTestsExecuted = $false
$json = $report | ConvertTo-Json -Depth 12
[IO.File]::WriteAllText((Join-Path $ReportDirectory 'windows-android-host.json'), $json, $utf8)
Write-Host $json
