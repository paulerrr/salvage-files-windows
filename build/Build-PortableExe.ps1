#requires -Version 5.1

[CmdletBinding()]
param(
    [ValidatePattern('^\d+\.\d+\.\d+\.\d+$')]
    [string] $Version = '1.0.0.0',

    [AllowEmptyString()]
    [string] $OutputPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'The portable executable must be built on Windows.'
}

$scriptPath = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    throw 'Windows could not determine the location of the build script.'
}
$scriptDirectory = Split-Path -Path $scriptPath -Parent
$repositoryRoot = Split-Path -Path $scriptDirectory -Parent
$buildModule = Join-Path $scriptDirectory 'RescueFiles.Build.psm1'
$mainScript = Join-Path $repositoryRoot 'Rescue-Files.ps1'
$coreModule = Join-Path $repositoryRoot 'RescueFiles.Core.psm1'
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repositoryRoot 'dist\Rescue Files.exe'
}
$resolvedOutput = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
    $OutputPath
)

Import-Module $buildModule -Force
if (-not (Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue)) {
    throw @'
PS2EXE is not installed. Open Windows PowerShell as administrator and run:
Install-Module ps2exe -Scope CurrentUser
'@
}

$temporaryScript = Join-Path ([IO.Path]::GetTempPath()) `
    ('Rescue-Files-combined-{0}.ps1' -f [guid]::NewGuid().ToString('N'))
try {
    [void](New-RescueCombinedScript -MainScriptPath $mainScript `
        -CoreModulePath $coreModule -OutputPath $temporaryScript)

    $outputDirectory = Split-Path -Path $resolvedOutput -Parent
    if (-not (Test-Path -LiteralPath $outputDirectory)) {
        [void](New-Item -ItemType Directory -Path $outputDirectory -Force)
    }

    Invoke-ps2exe -InputFile $temporaryScript -OutputFile $resolvedOutput `
        -Title 'Rescue Files' `
        -Description 'Safely copy personal files from an inaccessible Windows drive' `
        -Product 'Rescue Files' `
        -Company 'Rescue Files contributors' `
        -Copyright 'Copyright (c) 2026 Rescue Files contributors' `
        -Version $Version `
        -RequireAdmin `
        -SupportOS

    if (-not (Test-Path -LiteralPath $resolvedOutput -PathType Leaf)) {
        throw 'PS2EXE finished without creating the expected executable.'
    }

    Write-Host "Portable executable created:`n$resolvedOutput" -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $temporaryScript -PathType Leaf) {
        Remove-Item -LiteralPath $temporaryScript -Force
    }
}
