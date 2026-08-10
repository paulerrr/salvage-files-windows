Set-StrictMode -Version 2.0

function Get-RescueNtfsVolume {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Volume,

        [AllowNull()]
        [string] $ExcludeDriveLetter
    )

    @($Volume | Where-Object {
        $_.DriveLetter -and
        $_.FileSystem -eq 'NTFS' -and
        (-not $ExcludeDriveLetter -or
            [string]$_.DriveLetter -ne $ExcludeDriveLetter.TrimEnd(':'))
    })
}

function Get-RescueVolume {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string] $ExcludeDriveLetter
    )

    Get-RescueNtfsVolume -Volume @(Get-Volume) `
        -ExcludeDriveLetter $ExcludeDriveLetter
}

function Test-RescueExcludedProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    $Name -in @('Public', 'Default', 'Default User', 'All Users')
}

function Test-RescueJunction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Directory
    )

    if ($Directory.PSObject.Properties.Name -contains 'LinkType' -and
        $Directory.LinkType -eq 'Junction') {
        return $true
    }

    if ($Directory.PSObject.Properties.Name -contains 'Attributes') {
        return [bool]($Directory.Attributes -band [IO.FileAttributes]::ReparsePoint)
    }

    return $false
}

function Select-RescueProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $CandidateProfile,

        [Parameter(Mandatory)]
        [string] $SystemDriveLetter
    )

    $systemLetter = $SystemDriveLetter.TrimEnd(':')
    @($CandidateProfile | Where-Object {
        -not (Test-RescueExcludedProfile -Name $_.User) -and
        -not $_.IsJunction
    } | ForEach-Object {
        [PSCustomObject]@{
            Path = $_.Path
            Drive = [string]$_.Drive
            User = $_.User
            Label = $_.Label
            IsThisPC = ([string]$_.Drive -eq $systemLetter)
        }
    } | Sort-Object IsThisPC, Drive, User)
}

function ConvertFrom-RobocopySummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $Line
    )

    $result = [ordered]@{
        TotalFiles = [int64]0
        CopiedFiles = [int64]0
        TotalBytes = [int64]0
        CopiedBytes = [int64]0
        FoundFilesLine = $false
        FoundBytesLine = $false
    }

    foreach ($text in $Line) {
        if ($text -match '^\s*Files\s*:\s*(\d+)\s+(\d+)') {
            $result.TotalFiles = [int64]$Matches[1]
            $result.CopiedFiles = [int64]$Matches[2]
            $result.FoundFilesLine = $true
        }
        elseif ($text -match '^\s*Bytes\s*:\s*(\d+)\s+(\d+)') {
            $result.TotalBytes = [int64]$Matches[1]
            $result.CopiedBytes = [int64]$Matches[2]
            $result.FoundBytesLine = $true
        }
    }

    [PSCustomObject]$result
}

function Get-RescueSpaceCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, [long]::MaxValue)]
        [long] $BytesNeeded,

        [Parameter(Mandatory)]
        [ValidateRange(0, [long]::MaxValue)]
        [long] $BytesFree
    )

    [PSCustomObject]@{
        Fits = ($BytesNeeded -le $BytesFree)
        BytesNeeded = $BytesNeeded
        BytesFree = $BytesFree
        BytesShort = [math]::Max([int64]0, ($BytesNeeded - $BytesFree))
    }
}

function Test-RobocopySuccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, 255)]
        [int] $ExitCode
    )

    $ExitCode -lt 8
}

function Get-RobocopyErrorGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $Line
    )

    $parents = foreach ($text in $Line) {
        if ($text -notmatch '\bERROR\s+\d+') { continue }

        $path = $null
        if ($text -match '(?i)(?:Copying File|Copying Directory|Accessing Source Directory)\s+(.+?)\s*$') {
            $path = $Matches[1].Trim()
        }
        elseif ($text -match '([A-Za-z]:\\[^\r\n]+?)\s*$') {
            $path = $Matches[1].Trim()
        }

        if (-not $path) { continue }
        if ($path.EndsWith('\')) {
            $path.TrimEnd('\')
        }
        else {
            $path -replace '\\[^\\]*$', ''
        }
    }

    @($parents | Where-Object { $_ } | Group-Object | Sort-Object Count -Descending |
        ForEach-Object {
            [PSCustomObject]@{
                Folder = $_.Name
                Count = $_.Count
            }
        })
}

function Test-RescueSameVolume {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $SourceVolume,

        [Parameter(Mandatory)]
        [object] $DestinationVolume
    )

    foreach ($property in @('UniqueId', 'ObjectId', 'Path')) {
        if (($SourceVolume.PSObject.Properties.Name -contains $property) -and
            ($DestinationVolume.PSObject.Properties.Name -contains $property) -and
            $SourceVolume.$property -and $DestinationVolume.$property) {
            return ([string]$SourceVolume.$property -eq [string]$DestinationVolume.$property)
        }
    }

    ([string]$SourceVolume.DriveLetter).TrimEnd(':') -eq
        ([string]$DestinationVolume.DriveLetter).TrimEnd(':')
}

Export-ModuleMember -Function @(
    'Get-RescueNtfsVolume',
    'Get-RescueVolume',
    'Test-RescueExcludedProfile',
    'Test-RescueJunction',
    'Select-RescueProfile',
    'ConvertFrom-RobocopySummary',
    'Get-RescueSpaceCheck',
    'Test-RobocopySuccess',
    'Get-RobocopyErrorGroup',
    'Test-RescueSameVolume'
)
