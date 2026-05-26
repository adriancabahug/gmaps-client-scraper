param(
    [switch]$DryRun,
    [string]$City = "dallas"
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $scriptRoot "src" "config.ps1")
. (Join-Path $scriptRoot "src" "query-manager.ps1")
. (Join-Path $scriptRoot "src" "scraper-runner.ps1")
. (Join-Path $scriptRoot "src" "orchestrator.ps1")

Invoke-ScraperPipeline -DryRun:$DryRun -City $City
