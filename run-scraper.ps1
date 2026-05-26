param(
    [switch]$DryRun,
    [string]$City = "dallas"
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$scriptRoot\src\config.ps1"
. "$scriptRoot\src\query-manager.ps1"
. "$scriptRoot\src\scraper-runner.ps1"
. "$scriptRoot\src\orchestrator.ps1"

Invoke-ScraperPipeline -DryRun:$DryRun -City $City
