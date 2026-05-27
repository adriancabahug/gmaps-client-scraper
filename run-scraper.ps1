param(
    [switch]$DryRun,
    [string]$City = "dallas"
)

try {
    Write-Host "Booting scraper pipeline..."
    Write-Host "  PWD: $PWD"
    Write-Host "  PSScriptRoot: $PSScriptRoot"

    if (-not (Test-Path "$PSScriptRoot/queries.txt")) {
        throw "Missing queries.txt in $PSScriptRoot"
    }
    if (-not (Test-Path "$PSScriptRoot/config.json")) {
        throw "Missing config.json in $PSScriptRoot"
    }

    . "$PSScriptRoot/src/config.ps1"
    . "$PSScriptRoot/src/query-manager.ps1"
    . "$PSScriptRoot/src/scraper-runner.ps1"
    . "$PSScriptRoot/src/output-processor.ps1"
    . "$PSScriptRoot/src/orchestrator.ps1"

    Invoke-ScraperPipeline -DryRun:$DryRun -City $City
} catch {
    Write-Error "Pipeline failed: $_"
    exit 1
}
