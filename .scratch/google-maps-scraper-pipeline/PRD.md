# PRD: Google Maps Scraper Pipeline

Status: `ready-for-agent`

## Problem Statement

A solo operator in the Philippines needs to scrape business listings (name, phone, website, address, rating, email) for **Residential Roofing Contractors in Dallas, Texas** to build a cold-calling prospect list. They have no budget for paid APIs or proxies, no Docker experience, and need a reliable, restartable pipeline that doesn't require re-scraping on every crash.

## Solution

A PowerShell orchestration layer around the free, open-source `gosom/google-maps-scraper` Docker image. The pipeline:

- Uses a grid-scraping strategy over Dallas (2 km cells) to bypass Google's ~200-result per-query cap
- Manages scrape state so interrupted runs resume without data loss
- Post-processes raw JSON into a clean, deduplicated prospect list
- Encapsulates all Docker complexity behind simple PowerShell commands

## User Stories

1. As a solo operator, I want to scrape all roofing contractors in Dallas with a single command, so that I don't need to understand Docker flags or grid parameters.

2. As a solo operator, I want the scraper to cover the entire Dallas metro area, so that I don't miss prospects in any neighborhood.

3. As a solo operator, I want to extract phone numbers, websites, and emails for each business, so that I can cold-call them.

4. As a solo operator, I want the raw JSON deduplicated by `place_id`, so that businesses appearing in overlapping grid cells are only listed once.

5. As a solo operator, I want to filter out businesses that have no phone number, so that I don't waste time on unreachable leads.

6. As a solo operator, I want the pipeline to survive crashes and internet drops, so that I don't lose progress and re-scrape the same data.

7. As a solo operator, I want to configure the target city and bounding box in a simple config file, so that I can reuse the pipeline for other cities.

8. As a solo operator, I want output as both JSON and CSV, so that I can import prospects into a CRM or spreadsheet.

9. As a solo operator, I want the pipeline to validate my queries before running, so that I don't waste time on malformed searches.

10. As a solo operator, I want clear error messages when Docker is not installed or the image is missing, so that I know exactly what to fix.

## Implementation Decisions

### Module Architecture

The four modules interact in a strict pipeline:

```
Config ──► Query Manager ──► Scraper Runner ──► Output Processor
                                   │
                            gosom Docker Image
```

### Module 1: Config (`config.ps1`)

**Type:** Shallow

Stores reusable scrape configurations as a JSON file (`config.json`).

**Interface:**
- `Get-ScraperConfig` — reads and returns the config object
- `Get-LocationBBox -City` — returns bounding box `[minLat, minLon, maxLat, maxLon]` for a named city
- `Get-ConfigPath` — returns the path to the config file

**Schema (config.json):**
```json
{
  "docker": {
    "image": "gosom/google-maps-scraper",
    "tag": "latest"
  },
  "locations": {
    "dallas": {
      "bbox": [32.6, -96.85, 32.9, -96.65],
      "country": "US"
    }
  },
  "defaults": {
    "gridCellKm": 2.0,
    "depth": 1,
    "lang": "en",
    "outputDir": "gmaps-output"
  }
}
```

### Module 2: Query Manager (`query-manager.ps1`)

**Type:** Deep

Manages the list of search queries and their execution state for idempotency.

**State tracking:** Each query has a status: `Pending`, `Running`, or `Completed`. The state is persisted in a JSON state file (`scrape-state.json`) so the pipeline can resume after a crash.

**Interface:**
- `Get-QueryList` — reads queries from `queries.txt`, strips blanks/duplicates/invalid chars
- `Write-QueryState` — persists the current state to disk
- `Read-QueryState` — loads persisted state on resume
- `Get-PendingQueries` — returns only queries not yet completed
- `Mark-QueryStatus -Query -Status` — transitions a single query's state
- `New-QueryState` — initializes all queries as `Pending`

**State schema:**
```json
{
  "version": 1,
  "queries": [
    {
      "text": "Residential Roofing Contractors in Dallas, Texas",
      "status": "Completed",
      "cell": 1
    }
  ],
  "lastUpdated": "2026-05-27T12:00:00Z"
}
```

### Module 3: Scraper Runner (`scraper-runner.ps1`)

**Type:** Deep

Wraps the `docker run` command with all required flags. Only responsible for constructing and executing the Docker command, and returning the exit code.

**Interface:**
- `Invoke-Scraper -Queries -BBox -CellSize -Depth -Email -Json -OutputDir` — builds and runs the Docker command
- `Test-DockerInstalled` — checks if Docker is available, returns bool
- `Test-DockerImage` — checks if the required image is pulled
- `Get-DockerCommand` — returns the command string without executing (for debugging/testing)

**Flag mapping (Docker flag → module parameter):**
- `-depth` → `-Depth`
- `-email` → `-Email`
- `-json` → `-Json`
- `-grid-bbox` → derived from `$BBox`
- `-grid-cell` → `-CellSize`
- `-input` → queries file mount
- `-results` → output path mount

### Module 4: Output Processor (`output-processor.ps1`)

**Type:** Deep

Pure data transformation — takes raw JSON from Docker, deduplicates, filters, and exports.

**Interface:**
- `Process-Output -InputPath -Deduplicate -FilterPhonesOnly -ExportCsv` — main entry point
- `Import-RawResults -Path` — reads raw JSON
- `Remove-Duplicates -Results` — deduplicates by `place_id`, keeping first occurrence
- `Filter-HasPhone -Results` — removes entries without a phone number
- `Export-CsvResults -Results -Path` — writes clean CSV
- `Export-JsonResults -Results -Path` — writes clean JSON

**Deduplication rule:** When two records share the same `place_id`, keep the one with more fields populated (fallback: first seen).

### Main Orchestrator (`run-scraper.ps1`)

A single entry-point script that wires all four modules together:

1. Load config
2. Validate Docker is installed
3. Read queries and initialize/resume state
4. For each pending query:
   a. Build Docker command via Scraper Runner
   b. Execute
   c. Mark query as Completed
5. Process output: deduplicate, filter, export

## Testing Decisions

### What makes a good test

Tests should verify **external behavior only** — the input/output contract of each module's public functions. They should not test implementation details (e.g., whether a specific JSON file was written, only that the correct data is returned).

### Which modules will be tested

| Module | Priority | Test approach |
|---|---|---|
| **Output Processor** | Highest | Pure function tests — feed it sample JSON, assert dedup/filter/export results. No mocks needed. |
| **Query Manager** | High | Feed it query lists, assert state transitions and validation. Mock file I/O for isolation. |
| **Scraper Runner** | Medium | Mock `docker` execution, verify the constructed command string is correct. Integration test with real Docker skipped in CI. |

### Prior art

PowerShell Pester tests in the `tests/` directory. Each module gets a corresponding `tests/<module>.Tests.ps1` file. Test fixtures (sample JSON) live in `tests/fixtures/`.

## Out of Scope

- Automatic geocoding of city names to bounding boxes (coordinates are manually configured)
- Scraping Google Maps directly (the gosom Docker image handles all scraping)
- Web UI or dashboard for the pipeline
- Scheduled/cron-based recurring scraping
- Multi-city scraping in a single run (run the pipeline per city)
- Proxy configuration (the free tier doesn't use proxies; gosom's built-in proxy support is available but opt-in)
- WhatsApp/notifications on completion

## Further Notes

- The `bboxfinder.com` or `geojson.io` workflow is used to find bounding box coordinates manually
- Docker Desktop for Windows is the only prerequisite; installation instructions will be documented in the README
- The gosom Playwright cache (`gmaps-playwright-cache` Docker volume) is preserved between runs to avoid re-downloading browser binaries
