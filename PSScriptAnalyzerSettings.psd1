@{
    # This is an interactive, color-coded console application. Write-Host is
    # intentional because its messages must not enter the robocopy data stream.
    ExcludeRules = @('PSAvoidUsingWriteHost')
}
