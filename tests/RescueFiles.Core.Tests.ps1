BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'RescueFiles.Core.psm1') -Force
}

Describe 'Get-RescueNtfsVolume' {
    It 'keeps mounted NTFS volumes and excludes the source drive' {
        $volumes = @(
            [pscustomobject]@{ DriveLetter = 'C'; FileSystem = 'NTFS' }
            [pscustomobject]@{ DriveLetter = 'E'; FileSystem = 'NTFS' }
            [pscustomobject]@{ DriveLetter = 'F'; FileSystem = 'exFAT' }
            [pscustomobject]@{ DriveLetter = $null; FileSystem = 'NTFS' }
        )

        $result = Get-RescueNtfsVolume -Volume $volumes -ExcludeDriveLetter E

        $result.DriveLetter | Should -Be @('C')
    }
}

Describe 'profile selection' {
    It 'excludes built-in profiles and junctions, and sorts this PC last' {
        $profiles = @(
            [pscustomobject]@{ Path = 'C:\Users\Jamie'; Drive = 'C'; User = 'Jamie'; Label = 'Windows'; IsJunction = $false }
            [pscustomobject]@{ Path = 'E:\Users\Alex'; Drive = 'E'; User = 'Alex'; Label = 'Old PC'; IsJunction = $false }
            [pscustomobject]@{ Path = 'E:\Users\Public'; Drive = 'E'; User = 'Public'; Label = 'Old PC'; IsJunction = $false }
            [pscustomobject]@{ Path = 'E:\Users\Legacy'; Drive = 'E'; User = 'Legacy'; Label = 'Old PC'; IsJunction = $true }
        )

        $result = Select-RescueProfile -Profile $profiles -SystemDriveLetter C

        $result.User | Should -Be @('Alex', 'Jamie')
        $result[1].IsThisPC | Should -BeTrue
    }
}

Describe 'ConvertFrom-RobocopySummary' {
    It 'parses total and copied file and byte counts' {
        $result = ConvertFrom-RobocopySummary -Line (Get-Content "$PSScriptRoot/fixtures/robocopy-normal.txt")

        $result.TotalFiles | Should -Be 125
        $result.CopiedFiles | Should -Be 100
        $result.TotalBytes | Should -Be 987654321
        $result.CopiedBytes | Should -Be 876543210
        $result.FoundFilesLine | Should -BeTrue
        $result.FoundBytesLine | Should -BeTrue
    }

    It 'handles a zero-byte result' {
        $result = ConvertFrom-RobocopySummary -Line (Get-Content "$PSScriptRoot/fixtures/robocopy-zero-bytes.txt")

        $result.CopiedFiles | Should -Be 0
        $result.CopiedBytes | Should -Be 0
    }
}

Describe 'Get-RescueSpaceCheck' {
    It 'reports the exact shortage when the copy will not fit' {
        $result = Get-RescueSpaceCheck -BytesNeeded 1500 -BytesFree 1000

        $result.Fits | Should -BeFalse
        $result.BytesShort | Should -Be 500
    }

    It 'allows an exact fit' {
        (Get-RescueSpaceCheck -BytesNeeded 1000 -BytesFree 1000).Fits |
            Should -BeTrue
    }
}

Describe 'Test-RobocopySuccess' {
    It 'treats exit codes below 8 as success' {
        0..7 | ForEach-Object { Test-RobocopySuccess -ExitCode $_ | Should -BeTrue }
    }

    It 'treats exit code 8 and above as failure' {
        8, 16 | ForEach-Object { Test-RobocopySuccess -ExitCode $_ | Should -BeFalse }
    }
}

Describe 'Get-RobocopyErrorGroup' {
    It 'groups failures by parent folder' {
        $result = Get-RobocopyErrorGroup -Line (Get-Content "$PSScriptRoot/fixtures/robocopy-errors.txt")

        $result.Count | Should -Be 2
        $result[0].Folder | Should -Be 'E:\Users\Jamie\Pictures'
        $result[0].Count | Should -Be 2
        $result[1].Folder | Should -Be 'E:\Users\Jamie\Documents\Taxes'
    }
}

Describe 'Test-RescueSameVolume' {
    It 'uses the stable volume ID even when drive letters differ' {
        $source = [pscustomobject]@{ DriveLetter = 'E'; UniqueId = 'volume-1' }
        $destination = [pscustomobject]@{ DriveLetter = 'F'; UniqueId = 'volume-1' }

        Test-RescueSameVolume -SourceVolume $source -DestinationVolume $destination |
            Should -BeTrue
    }
}
