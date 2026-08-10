#requires -Version 5.1

# Copies files off a Windows drive taken from a computer that will not boot.
# The source is always read-only: no robocopy delete, move, mirror, or purge
# options are used anywhere in this script.

[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Wait-BeforeClose {
    [CmdletBinding()]
    param()

    [void](Read-Host "`nPress Enter to close")
}

if (-not (Test-IsAdministrator)) {
    Write-Host 'Windows will ask for permission to read the old drive.' -ForegroundColor Yellow
    try {
        $arguments = @(
            '-NoProfile'
            '-ExecutionPolicy'
            'Bypass'
            '-File'
            ('"{0}"' -f $PSCommandPath)
        )
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments -ErrorAction Stop
    }
    catch {
        Write-Host "`nPermission was not given, so nothing was copied or changed." -ForegroundColor Yellow
        Wait-BeforeClose
    }
    exit
}

Import-Module (Join-Path $PSScriptRoot 'RescueFiles.Core.psm1') -Force

try {
    $Host.UI.RawUI.WindowTitle = 'Rescue Files'
}
catch {
    # Some hosts do not allow their title to be changed. The rescue can continue.
}

function Write-Title {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Text
    )

    Write-Host ''
    Write-Host ('=' * 62) -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host ('=' * 62) -ForegroundColor Cyan
    Write-Host ''
}

function Read-NumberedChoice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Prompt,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Count
    )

    while ($true) {
        $answer = Read-Host "`n$Prompt (1-$Count, or Q to quit)"
        if ($answer -match '^[Qq]$') {
            Write-Host "`nNothing was copied or changed."
            exit
        }

        $number = 0
        if ([int]::TryParse($answer, [ref]$number) -and
            $number -ge 1 -and $number -le $Count) {
            return $number - 1
        }
        Write-Host "Please type one of the numbers shown, from 1 to $Count." -ForegroundColor Yellow
    }
}

function Read-YesNo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Prompt
    )

    while ($true) {
        $answer = Read-Host "$Prompt (Y or N)"
        if ($answer -match '^[Yy]$') { return $true }
        if ($answer -match '^[Nn]$') { return $false }
        Write-Host 'Please type Y for yes or N for no.' -ForegroundColor Yellow
    }
}

function Format-RescueSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [long] $Bytes
    )

    if ($Bytes -ge 1GB) { return ('{0:N1} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N1} KB' -f ($Bytes / 1KB)) }
    return ('{0:N0} bytes' -f $Bytes)
}

function Get-CurrentStandbySetting {
    [CmdletBinding()]
    param()

    $sleepSubgroup = '238c9fa8-0aad-41ed-83f4-97be242c8f20'
    $standbySetting = '29f6c1db-86da-48c5-9fdb-f2b67b1f44da'
    $activeOutput = @(& powercfg.exe /getactivescheme 2>&1)
    if ($LASTEXITCODE -ne 0) { return $null }

    $schemeText = $activeOutput -join [Environment]::NewLine
    if ($schemeText -notmatch '([0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})') {
        return $null
    }
    $scheme = $Matches[1]

    $queryOutput = @(& powercfg.exe /query $scheme $sleepSubgroup $standbySetting 2>&1)
    if ($LASTEXITCODE -ne 0) { return $null }
    $indexes = @($queryOutput | ForEach-Object {
        if ($_ -match '0x([0-9a-fA-F]{8})\s*$') { $Matches[1] }
    })
    if ($indexes.Count -lt 1) { return $null }

    [PSCustomObject]@{
        Scheme = $scheme
        Seconds = [Convert]::ToInt64($indexes[0], 16)
        SleepSubgroup = $sleepSubgroup
        StandbySetting = $standbySetting
    }
}

function Restore-StandbySetting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Setting
    )

    & powercfg.exe /setacvalueindex $Setting.Scheme $Setting.SleepSubgroup `
        $Setting.StandbySetting $Setting.Seconds 2>&1 | Out-Null
    & powercfg.exe /setactive $Setting.Scheme 2>&1 | Out-Null
}

function Get-VolumeAgain {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $DriveLetter
    )

    Get-Volume -DriveLetter $DriveLetter.TrimEnd(':') -ErrorAction Stop
}

Write-Title -Text "RESCUE FILES FROM A COMPUTER THAT WON'T START"
Write-Host 'This copies personal files from the old drive to a safe place.'
Write-Host 'It only reads the old drive. It never changes or deletes anything on it.'

Write-Title -Text 'STEP 1 OF 4 - Choose the files to rescue'
Write-Host 'Looking for user folders on every connected Windows drive...' -ForegroundColor Gray

$systemDriveLetter = $env:SystemDrive.TrimEnd(':')
$volumes = @(Get-RescueNtfsVolume -Volume @(Get-Volume))
$foundProfiles = foreach ($volume in $volumes) {
    $usersPath = '{0}:\Users' -f $volume.DriveLetter
    if (-not (Test-Path -LiteralPath $usersPath -PathType Container)) { continue }

    $directories = @(Get-ChildItem -LiteralPath $usersPath -Directory -Force `
        -ErrorAction SilentlyContinue)
    foreach ($directory in $directories) {
        [PSCustomObject]@{
            Path = $directory.FullName
            Drive = [string]$volume.DriveLetter
            User = $directory.Name
            Label = if ($volume.FileSystemLabel) { $volume.FileSystemLabel } else { 'no name' }
            IsJunction = Test-RescueJunction -Directory $directory
        }
    }
}

$profiles = @(Select-RescueProfile -Profile @($foundProfiles) `
    -SystemDriveLetter $systemDriveLetter)
if ($profiles.Count -eq 0) {
    Write-Host "`nNo user folders were found." -ForegroundColor Red
    Write-Host 'Make sure the old drive is plugged in and appears in File Explorer.'
    Wait-BeforeClose
    exit
}

Write-Host "`nThese user folders were found:`n"
for ($index = 0; $index -lt $profiles.Count; $index++) {
    $profile = $profiles[$index]
    $warning = if ($profile.IsThisPC) {
        " - this computer; probably not the old drive"
    }
    else { '' }
    $color = if ($profile.IsThisPC) { 'DarkGray' } else { 'White' }
    Write-Host ('  {0}. {1} ({2}:, {3}){4}' -f ($index + 1), $profile.User,
        $profile.Drive, $profile.Label, $warning) -ForegroundColor $color
}

$source = $profiles[(Read-NumberedChoice `
    -Prompt "Which person's files do you want to rescue?" -Count $profiles.Count)]
$sourceVolume = Get-VolumeAgain -DriveLetter $source.Drive

Write-Title -Text 'STEP 2 OF 4 - Choose where to save the files'
$targets = @(Get-RescueNtfsVolume -Volume @(Get-Volume) `
    -ExcludeDriveLetter $source.Drive | Sort-Object DriveLetter)
if ($targets.Count -eq 0) {
    Write-Host 'There is no suitable drive to save the rescued files to.' -ForegroundColor Red
    Write-Host 'Connect another drive formatted as NTFS, then run this tool again.'
    Wait-BeforeClose
    exit
}

Write-Host "Available places to save the files:`n"
for ($index = 0; $index -lt $targets.Count; $index++) {
    $targetItem = $targets[$index]
    $label = if ($targetItem.FileSystemLabel) { $targetItem.FileSystemLabel } else { 'no name' }
    $mainDrive = if ([string]$targetItem.DriveLetter -eq $systemDriveLetter) {
        " - this computer's main drive"
    }
    else { '' }
    Write-Host ('  {0}. {1}: ({2}) - {3} free{4}' -f ($index + 1),
        $targetItem.DriveLetter, $label, (Format-RescueSize $targetItem.SizeRemaining), $mainDrive)
}

$target = $targets[(Read-NumberedChoice -Prompt 'Where should the rescued files be saved?' `
    -Count $targets.Count)]
$target = Get-VolumeAgain -DriveLetter ([string]$target.DriveLetter)
if (Test-RescueSameVolume -SourceVolume $sourceVolume -DestinationVolume $target) {
    Write-Host "`nThe old files and the chosen destination are on the same drive." -ForegroundColor Red
    Write-Host 'Choose a different physical drive so the rescue stays safe.'
    Wait-BeforeClose
    exit
}

$destination = '{0}:\RESCUED - {1}' -f $target.DriveLetter, $source.User
$logFile = '{0}:\RESCUED - {1} - log.txt' -f $target.DriveLetter, $source.User

Write-Title -Text 'STEP 3 OF 4 - Check that there is enough room'
Write-Host 'Counting the files. This can take a while; please wait...' -ForegroundColor Gray

$robocopyCommon = @(
    '/E'
    '/B'
    '/XJ'
    '/XD'
    'AppData'
    '.cache'
    'OneDrive'
    '/R:1'
    '/W:1'
    '/NP'
    '/BYTES'
)
$listing = @(& robocopy.exe $source.Path $destination @robocopyCommon `
    /L /NFL /NDL /NJH 2>&1)
$listingCode = $LASTEXITCODE
if (-not (Test-RobocopySuccess -ExitCode $listingCode)) {
    Write-Host "`nWindows could not finish checking the old drive." -ForegroundColor Red
    Write-Host 'Nothing was copied or changed. Check the drive connection and try again.'
    Wait-BeforeClose
    exit
}

$summary = ConvertFrom-RobocopySummary -Line @($listing | ForEach-Object { [string]$_ })
if (-not $summary.FoundFilesLine -or -not $summary.FoundBytesLine) {
    Write-Host "`nWindows did not return a complete file count." -ForegroundColor Red
    Write-Host 'Nothing was copied or changed. Check the drive connection and try again.'
    Wait-BeforeClose
    exit
}

$target = Get-VolumeAgain -DriveLetter ([string]$target.DriveLetter)
$space = Get-RescueSpaceCheck -BytesNeeded $summary.CopiedBytes `
    -BytesFree ([long]$target.SizeRemaining)
Write-Host ''
Write-Host "  Copying from:  $($source.Path)"
Write-Host "  Copying to:    $destination"
Write-Host ''
Write-Host ('  Files left to copy: {0:N0}' -f $summary.CopiedFiles)
Write-Host ('  Space needed:       {0}' -f (Format-RescueSize $summary.CopiedBytes))
Write-Host ('  Space available:    {0}' -f (Format-RescueSize $target.SizeRemaining))

if (-not $space.Fits) {
    Write-Host "`nThere is not enough room on that drive." -ForegroundColor Red
    Write-Host ('You need {0} more. Use a larger drive or free some space, then try again.' -f `
        (Format-RescueSize $space.BytesShort))
    Wait-BeforeClose
    exit
}

if ($summary.TotalFiles -eq 0) {
    Write-Host "`nThere are no files to rescue in this folder." -ForegroundColor Yellow
    Wait-BeforeClose
    exit
}

if ($summary.CopiedFiles -eq 0) {
    Write-Host "`nAll of these files are already at the destination." -ForegroundColor Green
    Write-Host 'Nothing else needs to be copied.'
    Wait-BeforeClose
    exit
}

Write-Host "`nWeb browser data, temporary files, and OneDrive are skipped on purpose." -ForegroundColor Gray
Write-Host 'Documents, Downloads, Desktop, Pictures, Music, and Videos are included.' -ForegroundColor Gray
Write-Host ''
Write-Host 'It is safe to run this rescue again.' -ForegroundColor Green
Write-Host 'Files already copied are skipped, so closing the window will not ruin the rescue.'
if (-not (Read-YesNo -Prompt "Start copying now?")) {
    Write-Host "`nNothing was copied or changed."
    Wait-BeforeClose
    exit
}

$sourceVolume = Get-VolumeAgain -DriveLetter $source.Drive
$target = Get-VolumeAgain -DriveLetter ([string]$target.DriveLetter)
if (Test-RescueSameVolume -SourceVolume $sourceVolume -DestinationVolume $target) {
    Write-Host "`nThe drive letters changed, and copying would no longer be safe." -ForegroundColor Red
    Write-Host 'Nothing was copied. Disconnect and reconnect the drives, then try again.'
    Wait-BeforeClose
    exit
}

Write-Title -Text 'STEP 4 OF 4 - Copy the files'
Write-Host 'A large rescue can take several hours.'
Write-Host 'If it stops, run this tool again and it will continue by skipping files already copied.'
Write-Host ''

$standbySetting = Get-CurrentStandbySetting
$started = Get-Date
$copyCode = 16
try {
    if ($standbySetting) {
        & powercfg.exe /change standby-timeout-ac 0 2>&1 | Out-Null
    }
    else {
        Write-Host 'Windows sleep could not be turned off automatically.' -ForegroundColor Yellow
        Write-Host 'Keep this computer awake until the copy finishes.' -ForegroundColor Yellow
    }

    & robocopy.exe $source.Path $destination @robocopyCommon `
        /TEE ("/LOG:{0}" -f $logFile)
    $copyCode = $LASTEXITCODE
}
finally {
    if ($standbySetting) {
        try {
            Restore-StandbySetting -Setting $standbySetting
        }
        catch {
            Write-Host 'Windows could not restore the previous sleep setting.' -ForegroundColor Yellow
            Write-Host 'You can change sleep normally in Windows Settings.' -ForegroundColor Yellow
        }
    }
}

$elapsed = (Get-Date) - $started
$errorGroups = @()
if (Test-Path -LiteralPath $logFile -PathType Leaf) {
    $errorGroups = @(Get-RobocopyErrorGroup -Line @(Get-Content -LiteralPath $logFile))
}

Write-Title -Text 'FINISHED'
Write-Host ('  Time taken: {0:hh\:mm\:ss}' -f $elapsed)
Write-Host "  Saved to:   $destination"
Write-Host "  Details:    $logFile"
Write-Host ''

if ((Test-RobocopySuccess -ExitCode $copyCode) -and $errorGroups.Count -eq 0) {
    Write-Host 'Your files were copied successfully.' -ForegroundColor Green
}
elseif ($errorGroups.Count -gt 0) {
    $failureCount = ($errorGroups | Measure-Object -Property Count -Sum).Sum
    Write-Host ("Most files were copied, but {0:N0} problem(s) were reported." -f $failureCount) `
        -ForegroundColor Yellow
    Write-Host "`nThe problems were grouped in these folders:"
    $errorGroups | Select-Object -First 8 | ForEach-Object {
        Write-Host ('  {0:N0} in {1}' -f $_.Count, $_.Folder) -ForegroundColor Gray
    }
    if ($errorGroups.Count -eq 1) {
        Write-Host "`nThe problems are concentrated in one folder. That is often disposable data."
        Write-Host 'Check your important files in the saved folder before disconnecting either drive.'
    }
    else {
        Write-Host "`nProblems across several folders can mean the old drive is failing." -ForegroundColor Yellow
        Write-Host 'Stop using the old drive and ask a computer repair professional for help.'
    }
}
else {
    Write-Host 'The copy did not finish.' -ForegroundColor Red
    Write-Host 'Run this tool again. It will skip files already copied and continue the rescue.'
}

Write-Host "`nOpen the saved folder and check that your important files look right."
Wait-BeforeClose
