Param(
    [Parameter(HelpMessage = "The GitHub actor running the action", Mandatory = $false)]
    [string] $actor,
    [Parameter(HelpMessage = "The GitHub token running the action", Mandatory = $false)]
    [string] $token,
    [Parameter(HelpMessage = "Specifies the parent telemetry scope for the telemetry signal", Mandatory = $false)]
    [string] $parentTelemetryScopeJson = '{}',
    [Parameter(HelpMessage = "Name of the online environment", Mandatory = $true)]
    [string] $environmentName,
    [Parameter(HelpMessage = "Admin center API credentials", Mandatory = $false)]
    [string] $adminCenterApiCredentials,
    [Parameter(HelpMessage = "Reuse environment if it exists", Mandatory = $false)]
    [bool] $reUseExistingEnvironment,
    [Parameter(HelpMessage = "Direct Commit (Y/N)", Mandatory = $false)]
    [bool] $directCommit    
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0
$telemetryScope = $null

# IMPORTANT: No code that can fail should be outside the try/catch

try {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-Helper.ps1" -Resolve)
    $branch = "$(if (!$directCommit) { [System.IO.Path]::GetRandomFileName() })"
    $serverUrl = CloneIntoNewFolder -actor $actor -token $token -branch $branch
    $repoBaseFolder = Get-Location
    $BcContainerHelperPath = DownloadAndImportBcContainerHelper -baseFolder $repoBaseFolder
    import-module (Join-Path -path $PSScriptRoot -ChildPath "..\TelemetryHelper.psm1" -Resolve)
    $telemetryScope = CreateScope -eventId 'DO0073' -parentTelemetryScopeJson $parentTelemetryScopeJson

    Write-Host "Reading $ALGoSettingsFile"
    $settingsJson = Get-Content $ALGoSettingsFile -Encoding UTF8 | ConvertFrom-Json

    CreateDevEnv `
        -kind cloud `
        -caller GitHubActions `
        -environmentName $environmentName `
        -reUseExistingEnvironment:$reUseExistingEnvironment `
        -baseFolder $repoBaseFolder `
        -adminCenterApiCredentials ($adminCenterApiCredentials | ConvertFrom-Json | ConvertTo-HashTable)

    CommitFromNewFolder -serverUrl $serverUrl -commitMessage "Create a development environment $environmentName" -branch $branch

    TrackTrace -telemetryScope $telemetryScope
}
catch {
    OutputError -message "Creating a development environment failed.$([environment]::Newline) $($_.Exception.Message)"
    TrackException -telemetryScope $telemetryScope -errorRecord $_
}
finally {
    CleanupAfterBcContainerHelper -bcContainerHelperPath $bcContainerHelperPath
}
