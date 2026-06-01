#!/usr/bin/env pwsh
#Requires -Version 7

<#
.SYNOPSIS
    Scrape Google Maps business listings via gosom/google-maps-scraper Docker image.

.DESCRIPTION
    Single-shot scraper for GitHub Actions. Writes query to temp file, runs Docker
    container, reads NDJSON output, deduplicates by place_id, filters for phone-present
    entries, and exports CSV.

.PARAMETER Query
    Search query string (e.g. "Residential Roofing Contractors in Dallas, Texas").

.PARAMETER BBox
    Bounding box as array [minLat, minLon, maxLat, maxLon].

.PARAMETER CellSize
    Grid cell size in kilometres. Default: 2.0

.PARAMETER Depth
    Search depth. Default: 1

.PARAMETER Email
    Switch to enable email extraction.

.PARAMETER OutDir
    Output directory. Default: "gmaps-output"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Query,

    [Parameter(Mandatory)]
    [array]$BBox,

    [double]$CellSize = 2.0,

    [int]$Depth = 1,

    [switch]$Email,

    [string]$OutDir = "gmaps-output"
)

$ErrorActionPreference = "Stop"

# ── Validate bounding box ─────────────────────────────────────────────────────
if ($BBox.Count -ne 4) {
    throw "BBox must contain exactly 4 elements: [minLat, minLon, maxLat, maxLon]"
}

$minLat, $minLon, $maxLat, $maxLon = $BBox

# ── Prepare directories ───────────────────────────────────────────────────────
$tempDir = [System.IO.Path]::GetTempPath()
$queriesFile = Join-Path $tempDir "queries.txt"
$rawOutputFile = Join-Path $tempDir "results.json"

$null = New-Item -ItemType Directory -Force -Path $OutDir

# ── Write query to temp file ──────────────────────────────────────────────────
$Query | Set-Content -Path $queriesFile -Encoding UTF8
$null = New-Item -ItemType File -Force -Path $rawOutputFile

# ── Build docker run command ──────────────────────────────────────────────────
$dockerArgs = @(
    "run", "--rm",
    "-v", "${queriesFile}:/input/queries.txt",
    "-v", "${rawOutputFile}:/output/results.json",
    "gosom/google-maps-scraper",
    "-input", "/input/queries.txt",
    "-results", "/output/results.json",
    "-depth", $Depth,
    "-grid-bbox", "${minLat},${minLon},${maxLat},${maxLon}",
    "-grid-cell", $CellSize
)

if ($Email) {
    $dockerArgs += "-email"
}

# ── Execute scraper ───────────────────────────────────────────────────────────
Write-Host "Running gosom/google-maps-scraper..."
& docker @dockerArgs

if ($LASTEXITCODE -ne 0) {
    throw "Docker scraper exited with code $LASTEXITCODE"
}

# ── Check output exists ───────────────────────────────────────────────────────
if (-not (Test-Path $rawOutputFile)) {
    throw "Expected output file not found: $rawOutputFile"
}

# ── Process NDJSON: deduplicate by place_id, filter phone-present, export CSV ─
$results = Get-Content -Path $rawOutputFile -Encoding UTF8 |
    Where-Object { $_.Trim().StartsWith("{") } |
    ForEach-Object { $_ | ConvertFrom-Json -Depth 10 } |
    Where-Object { $_.phone -and ($_.phone -ne "") } |
    Group-Object -Property place_id |
    ForEach-Object { $_.Group | Select-Object -First 1 } |
    Select-Object -Property @(
        @{ Name = "Name";     Expression = { $_.title } },
        @{ Name = "Phone";    Expression = { $_.phone } },
        @{ Name = "Address";  Expression = { $_.address } },
        @{ Name = "Rating";   Expression = { $_.review_rating } },
        @{ Name = "Website";  Expression = { $_.web_site } }
    )

# ── Export CSV ────────────────────────────────────────────────────────────────
$csvPath = Join-Path $OutDir "prospects.csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

Write-Host "Exported $($results.Count) prospects to $csvPath"
