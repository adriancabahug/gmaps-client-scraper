$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here/../src/config.ps1"
. "$here/../src/query-manager.ps1"
. "$here/../src/scraper-runner.ps1"
. "$here/../src/output-processor.ps1"
. "$here/../src/orchestrator.ps1"

Describe "Invoke-ScraperPipeline" {
    Context "dry run" {
        It "walks through queries and marks them completed in state" {
            $configFile = [System.IO.Path]::GetTempFileName()
            @"
{
  "locations": {
    "dallas": {
      "bbox": [32.6, -96.85, 32.9, -96.65]
    }
  }
}
"@ | Set-Content -Path $configFile

            $queriesFile = [System.IO.Path]::GetTempFileName()
            "Residential Roofing Contractors in Dallas, Texas" | Set-Content -Path $queriesFile

            $stateFile = [System.IO.Path]::GetTempFileName()
            Remove-Item -Path $stateFile -Force

            $output = Invoke-ScraperPipeline -DryRun -ConfigPath $configFile -QueriesPath $queriesFile -StatePath $stateFile

            $output -match "docker run" | Should Be $true

            $stateFileExists = Test-Path -Path $stateFile
            $stateFileExists | Should Be $true

            $state = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
            $state.queries.Count | Should Be 1
            $state.queries[0].status | Should Be "Completed"

            Remove-Item -Path $configFile -Force
            Remove-Item -Path $queriesFile -Force
            Remove-Item -Path $stateFile -Force
        }
    }

    Context "live execution" {
        It "throws when docker is not installed" {
            Mock Test-DockerInstalled { return $false }

            $configFile = [System.IO.Path]::GetTempFileName()
            @"
{ "locations": { "dallas": { "bbox": [32.6, -96.85, 32.9, -96.65] } } }
"@ | Set-Content -Path $configFile

            $queriesFile = [System.IO.Path]::GetTempFileName()
            "test query" | Set-Content -Path $queriesFile

            $stateFile = [System.IO.Path]::GetTempFileName()
            Remove-Item -Path $stateFile -Force

            { Invoke-ScraperPipeline -ConfigPath $configFile -QueriesPath $queriesFile -StatePath $stateFile } | Should Throw "Docker is not installed"

            Remove-Item -Path $configFile -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $queriesFile -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $stateFile -Force -ErrorAction SilentlyContinue
        }

        It "executes docker and marks queries completed" {
            Mock Test-DockerInstalled { return $true }
            Mock Invoke-DockerCommand { return 0 }

            $configFile = [System.IO.Path]::GetTempFileName()
            @"
{ "locations": { "dallas": { "bbox": [32.6, -96.85, 32.9, -96.65] } } }
"@ | Set-Content -Path $configFile

            $queriesFile = [System.IO.Path]::GetTempFileName()
            "test query" | Set-Content -Path $queriesFile

            $stateFile = [System.IO.Path]::GetTempFileName()
            Remove-Item -Path $stateFile -Force

            Invoke-ScraperPipeline -ConfigPath $configFile -QueriesPath $queriesFile -StatePath $stateFile

            $state = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
            $state.queries[0].status | Should Be "Completed"

            Remove-Item -Path $configFile -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $queriesFile -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $stateFile -Force -ErrorAction SilentlyContinue
        }

        It "resets Running queries from stale state to Pending at startup" {
            Mock Test-DockerInstalled { return $true }
            Mock Invoke-DockerCommand { return 0 }

            $configFile = [System.IO.Path]::GetTempFileName()
            @"
{ "locations": { "dallas": { "bbox": [32.6, -96.85, 32.9, -96.65] } } }
"@ | Set-Content -Path $configFile

            $queriesFile = [System.IO.Path]::GetTempFileName()
            "test query" | Set-Content -Path $queriesFile

            $stateFile = [System.IO.Path]::GetTempFileName()
            @"
{
  "version": 1,
  "queries": [
    { "text": "test query", "status": "Running", "cell": 1 }
  ],
  "lastUpdated": "2026-05-27T12:00:00Z"
}
"@ | Set-Content -Path $stateFile

            Invoke-ScraperPipeline -ConfigPath $configFile -QueriesPath $queriesFile -StatePath $stateFile

            $state = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
            $state.queries[0].status | Should Be "Completed"

            Remove-Item -Path $configFile -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $queriesFile -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $stateFile -Force -ErrorAction SilentlyContinue
        }

        It "resets Running to Pending and re-throws when Docker fails" {
            Mock Test-DockerInstalled { return $true }
            Mock Invoke-DockerCommand { throw "Docker crashed" }

            $configFile = [System.IO.Path]::GetTempFileName()
            @"
{ "locations": { "dallas": { "bbox": [32.6, -96.85, 32.9, -96.65] } } }
"@ | Set-Content -Path $configFile

            $queriesFile = [System.IO.Path]::GetTempFileName()
            "test query" | Set-Content -Path $queriesFile

            $stateFile = [System.IO.Path]::GetTempFileName()
            Remove-Item -Path $stateFile -Force

            { Invoke-ScraperPipeline -ConfigPath $configFile -QueriesPath $queriesFile -StatePath $stateFile } | Should Throw "Docker crashed"

            $state = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
            $state.queries[0].status | Should Be "Pending"

            Remove-Item -Path $configFile -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $queriesFile -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $stateFile -Force -ErrorAction SilentlyContinue
        }

        It "processes output results when docker succeeds" {
            Mock Test-DockerInstalled { return $true }
            Mock Invoke-DockerCommand { return 0 }

            $configFile = [System.IO.Path]::GetTempFileName()
            @"
{ "locations": { "dallas": { "bbox": [32.6, -96.85, 32.9, -96.65] } } }
"@ | Set-Content -Path $configFile

            $queriesFile = [System.IO.Path]::GetTempFileName()
            "test query" | Set-Content -Path $queriesFile

            $stateFile = [System.IO.Path]::GetTempFileName()
            Remove-Item -Path $stateFile -Force

            mkdir gmaps-output -Force | Out-Null
            Copy-Item "$here\fixtures\sample-results.json" "gmaps-output/results.json" -Force

            Invoke-ScraperPipeline -ConfigPath $configFile -QueriesPath $queriesFile -StatePath $stateFile

            $prospectsJson = Test-Path "gmaps-output/prospects.json"
            $prospectsCsv = Test-Path "gmaps-output/prospects.csv"
            $prospectsJson | Should Be $true
            $prospectsCsv | Should Be $true

            Remove-Item -Path $configFile -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $queriesFile -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $stateFile -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "gmaps-output" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
