# Google Maps Scraper — Domain Glossary

## Concept

A PowerShell orchestration pipeline that wraps the `gosom/google-maps-scraper` Docker image. It scrapes business listings from Google Maps for a target area, deduplicates the results, and exports a clean prospect list for cold-calling outreach.

## Glossary

| Term | Definition |
|---|---|
| **Query** | A search string passed to Google Maps, e.g. "Residential Roofing Contractors in Dallas, Texas" |
| **State** | A persisted JSON file tracking which queries are `Pending`, `Running`, or `Completed` — enables crash recovery and resume |
| **Bounding box (bbox)** | Four coordinates `[minLat, minLon, maxLat, maxLon]` defining a rectangular area over a city |
| **Grid cell** | A subdivision of the bounding box (e.g. 2 km) — the scraper searches each cell independently to bypass the ~200-result cap |
| **Grid scraping** | Strategy of dividing a city into overlapping cells so Google's per-query result cap doesn't limit total coverage |
| **Dry run** | Pipeline mode that prints the `docker run` command without executing it — used for verification |
| **Place ID** | Google's unique identifier for a business listing — used for deduplication |
| **Prospect** | A scraped business record that has passed filtering (has phone, deduplicated) |

## Key Decisions

- **Coordinates are manual** — bounding boxes are configured in `config.json`, not geocoded. Use `bboxfinder.com` to draw them.
- **No proxies** — the free-tier pipeline runs without residential proxies. The gosom image supports them optionally.
- **Docker prerequisite** — the scraper itself runs inside a Docker container. The pipeline orchestrates it from outside.

## ADRs

None yet.
