Set-StrictMode -Version 2.0

function New-RescueCombinedScript {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
        [string] $MainScriptPath,

        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
        [string] $CoreModulePath,

        [Parameter(Mandatory)]
        [string] $OutputPath
    )

    $mainScript = Get-Content -LiteralPath $MainScriptPath -Raw
    $coreModule = Get-Content -LiteralPath $CoreModulePath -Raw

    $importLine = "Import-Module (Join-Path `$PSScriptRoot 'RescueFiles.Core.psm1') -Force"
    if (-not $mainScript.Contains($importLine)) {
        throw 'The main script no longer contains the expected core-module import.'
    }
    $mainScript = $mainScript.Replace($importLine, '')

    $coreModule = [regex]::Replace(
        $coreModule,
        '(?m)^Set-StrictMode -Version 2\.0\s*',
        '',
        [Text.RegularExpressions.RegexOptions]::None
    )
    $coreModule = [regex]::Replace(
        $coreModule,
        '(?ms)^Export-ModuleMember -Function @\(.*?\)\s*$',
        '',
        [Text.RegularExpressions.RegexOptions]::None
    )

    $insertionPoint = 'Set-StrictMode -Version 2.0'
    $position = $mainScript.IndexOf($insertionPoint, [StringComparison]::Ordinal)
    if ($position -lt 0) {
        throw 'The main script no longer contains the expected insertion point.'
    }

    $combined = $mainScript.Insert($position, "$coreModule`r`n`r`n")
    if ($PSCmdlet.ShouldProcess($OutputPath, 'Create combined rescue script')) {
        $outputDirectory = Split-Path -Path $OutputPath -Parent
        if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
            [void](New-Item -ItemType Directory -Path $outputDirectory -Force)
        }
        Set-Content -LiteralPath $OutputPath -Value $combined -Encoding UTF8

        Get-Item -LiteralPath $OutputPath
    }
}

Export-ModuleMember -Function 'New-RescueCombinedScript'
