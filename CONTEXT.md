# Context: Google Maps Scraper Pipeline

## Objective

Scrape business listings (name, phone, website, address, rating) for Residential Roofing Contractors in Dallas, Texas to build a cold-calling prospect list. Absolutely free — no paid APIs, proxies, or services.

## Solution

A single PowerShell script (`run-scraper.ps1`) orchestrated via GitHub Actions. It runs the open-source `gosom/google-maps-scraper` Docker image on an ephemeral Ubuntu runner, processes the NDJSON output to deduplicate and filter, and commits a CSV back to the repo.

## Architecture

```
Trigger (manual) → GitHub Actions (ubuntu-latest) → Docker (gosom) → NDJSON → Dedup → Filter → CSV → Commit to repo
```

Everything is in one file — no modules, no config files, no state machine.

## Key Decisions

**GitHub Actions over local execution.**
Local Docker Desktop has admin restrictions. GitHub provides 2,000 free minutes/month on cloud runners with Docker pre-installed.

**Single script file over modules.**
Multiple files with dot-source paths caused cross-platform path issues (Join-Path, backslash/forward-slash). One top-to-bottom script eliminates loading order bugs and works identically on Windows PowerShell Core and Linux pwsh.

**No state machine / resume logic.**
Each workflow run is on a fresh ephemeral VM. If it fails, the user re-runs. No state file, no "Pending/Running/Completed" tracking, no crash recovery.

**No config file.**
Parameters are passed directly to the script. Bounding box coordinates are hardcoded in the workflow YAML. This avoids file-not-found errors and JSON parsing complexity.

**`& docker @dockerArgs` over `Invoke-Expression`.**
Direct splatting is safer, more readable, and avoids quoting/escaping bugs that plagued string concatenation approaches. Exit codes propagate naturally via `$LASTEXITCODE`.

**NDJSON line-by-line parsing over JSON array.**
The gosom scraper outputs one JSON object per line (NDJSON). `Get-Content | ConvertFrom-Json` per line handles this natively. `ConvertFrom-Json` on the whole file fails when it encounters multiple root objects.

**`Group-Object -Property place_id` for dedup.**
Pure PowerShell, no HashSet needed. Keeps the first occurrence per group. Streamed via pipeline.

**CSV only as output format.**
Excel-ready. Columns: Name, Phone, Address, Rating, Website. No JSON output — the raw NDJSON is lost after processing.

## Anti-Requirments (What We Chose NOT To Build)

- No multi-query batching — one query per run
- No proxy configuration
- No web UI or dashboard
- No scheduled/cron recurring scraping
- No geocoding — bounding box coordinates are manual
- No tests — the script is simple enough to verify by running
- No Docker installation checks — guaranteed on ubuntu-latest
- No local development workflow — the script only runs in CI
