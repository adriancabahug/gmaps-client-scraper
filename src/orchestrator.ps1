function Invoke-ScraperPipeline {
    param(
        [switch]$DryRun,
        [string]$ConfigPath = "config.json",
        [string]$QueriesPath = "queries.txt",
        [string]$StatePath = "scrape-state.json",
        [string]$City = "dallas"
    )

    $queries = Get-QueryList -Path $QueriesPath
    $bbox = Get-LocationBBox -City $City -ConfigPath $ConfigPath

    $existingState = Read-QueryState -Path $StatePath
    if ($existingState) {
        $state = $existingState
        $state = Reset-StuckRunning -State $state
    } else {
        $state = New-QueryState -Queries $queries
    }

    $pending = Get-PendingQueries -State $state

    if ($pending.Count -eq 0) {
        Write-Host "All queries completed. Nothing to scrape."
        return
    }
    Write-Host "Pending queries: $($pending.Count)"

    if (-not $DryRun) {
        if (-not (Test-DockerInstalled)) {
            throw "Docker is not installed. Install Docker Desktop (https://www.docker.com/products/docker-desktop/) and try again."
        }
        New-Item -ItemType Directory -Path "gmaps-output" -Force | Out-Null
    }

    $pending | Set-Content -Path $QueriesPath -Force

    $outputDir = "gmaps-output"
    $rawResultsFile = "$outputDir/results.json"
    $cleanJsonFile = "$outputDir/prospects.json"
    $cleanCsvFile = "$outputDir/prospects.csv"

    $cmd = Get-DockerCommand -BBox $bbox -Email -OutputDir $outputDir

    if ($DryRun) {
        "[DRY-RUN] $cmd"
    } else {
        foreach ($queryText in $pending) {
            $state = Mark-QueryStatus -State $state -Query $queryText -Status "Running"
        }
        Write-QueryState -State $state -Path $StatePath

        try {
            $exitCode = Invoke-DockerCommand -Command $cmd
            if ($exitCode -ne 0) {
                throw "Docker command failed with exit code $exitCode"
            }

            if (Test-Path -Path $rawResultsFile) {
                $clean = Import-RawResults -Path $rawResultsFile | Remove-Duplicates | Filter-HasPhone
                if ($clean) {
                    $clean | Export-CsvResults -Path $cleanCsvFile
                    $clean | ConvertTo-Json -Depth 4 | Set-Content -Path $cleanJsonFile -Force
                }
            }
        } catch {
            $state = Reset-StuckRunning -State $state
            Write-QueryState -State $state -Path $StatePath
            throw
        }
    }

    foreach ($queryText in $pending) {
        $state = Mark-QueryStatus -State $state -Query $queryText -Status "Completed"
    }

    Write-QueryState -State $state -Path $StatePath
}
