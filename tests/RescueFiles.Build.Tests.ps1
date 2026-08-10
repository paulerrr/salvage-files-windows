BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'build' 'RescueFiles.Build.psm1') -Force
    $script:RepositoryRoot = Split-Path $PSScriptRoot -Parent
}

Describe 'New-RescueCombinedScript' {
    BeforeEach {
        $script:CombinedPath = Join-Path $TestDrive 'Rescue-Files-combined.ps1'
        New-RescueCombinedScript `
            -MainScriptPath (Join-Path $RepositoryRoot 'Rescue-Files.ps1') `
            -CoreModulePath (Join-Path $RepositoryRoot 'RescueFiles.Core.psm1') `
            -OutputPath $CombinedPath | Out-Null
        $script:CombinedContent = Get-Content -LiteralPath $CombinedPath -Raw
    }

    It 'creates a self-contained script with the core functions' {
        $CombinedContent | Should -Match 'function ConvertFrom-RobocopySummary'
        $CombinedContent | Should -Match 'function Test-RescueSameVolume'
        $CombinedContent | Should -Not -Match 'Import-Module.*RescueFiles\.Core'
        $CombinedContent | Should -Not -Match 'Export-ModuleMember'
    }

    It 'produces syntactically valid PowerShell' {
        $tokens = $null
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile(
            $CombinedPath,
            [ref]$tokens,
            [ref]$errors
        )

        $errors | Should -BeNullOrEmpty
    }

    It 'does not introduce destructive robocopy switches' {
        $CombinedContent | Should -Not -Match '(?i)/(MIR|MOVE|MOV|PURGE)\b'
    }

    It 'grants Everyone full control only through the destination setup' {
        $CombinedContent | Should -Match 'function Grant-RescueDestinationAccess'
        $CombinedContent | Should -Match "SecurityIdentifier\('S-1-1-0'\)"
        $CombinedContent | Should -Match `
            'Grant-RescueDestinationAccess -DestinationPath \$destination'
        $CombinedContent | Should -Not -Match '(?i)/COPY(?:ALL|:S)\b'
    }
}

Describe 'Build-PortableExe.ps1 compatibility' {
    BeforeAll {
        $script:BuilderContent = Get-Content `
            -LiteralPath (Join-Path $RepositoryRoot 'build' 'Build-PortableExe.ps1') `
            -Raw
    }

    It 'does not evaluate PSScriptRoot in a parameter default' {
        $BuilderContent | Should -Not -Match `
            '(?s)\[string\]\s+\$OutputPath\s*=.*?\$PSScriptRoot'
        $BuilderContent | Should -Match '\$MyInvocation\.MyCommand\.Path'
    }

    It 'does not request a companion configuration file' {
        $BuilderContent | Should -Not -Match '(?i)-LongPaths\b'
        $BuilderContent | Should -Not -Match '(?i)-ConfigFile\b'
    }
}
