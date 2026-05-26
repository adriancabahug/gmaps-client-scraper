# Google Maps Scraper Pipeline

PowerShell pipeline that scrapes business listings from Google Maps using the `gosom/google-maps-scraper` Docker image.

## Prerequisites

### Docker Desktop (Required)

1. Download from [docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/)
2. Install and restart your computer
3. Docker runs in the system tray — verify by opening PowerShell and running `docker --version`

## Quick Start

```powershell
# Dry run — prints the Docker command without executing
.\run-scraper.ps1 -DryRun

# Live run — requires Docker to be running
.\run-scraper.ps1
```

### What happens

1. Reads the search query from `queries.txt`
2. Loads the Dallas bounding box from `config.json`
3. Creates/reads state file for resume support
4. Runs the Docker container with grid scraping (2 km cells)
5. Saves scraped results to `gmaps-output/results.json`

## Configuration

### Change city

1. Open `config.json` and set the bounding box coordinates for your target city
2. Get coordinates from [bboxfinder.com](http://bboxfinder.com) — draw a box over your city, copy the 4 values
3. Update `queries.txt` with your search term (e.g., "Plumbers in Austin, Texas")

### Options

```powershell
.\run-scraper.ps1 -City dallas        # Which city (matches config.json key)
.\run-scraper.ps1 -DryRun             # Print command only, don't execute
```

## Project Structure

```
src/
  config.ps1          — Read bounding boxes
  query-manager.ps1   — Query validation + state machine
  scraper-runner.ps1  — Docker command builder + checks
  orchestrator.ps1    — Pipeline wiring
tests/
  config.Tests.ps1
  query-manager.Tests.ps1
  scraper-runner.Tests.ps1
  orchestrator.Tests.ps1
config.json           — Bounding box per city
queries.txt           — Search queries
scrape-state.json     — Auto-created, tracks progress
gmaps-output/         — Scraped results (created after live run)
```

## Running Tests

```powershell
Invoke-Pester .\tests\
```

## Resume on Crash

If the script is interrupted (power loss, Docker crash, network drop), re-run `.\run-scraper.ps1`. It reads the `scrape-state.json` file and skips already-completed queries.
