# ADR-0001: Orchestrate gosom Docker Image via PowerShell

**Status:** Accepted

## Context

We need to scrape Google Maps business listings for cold-calling prospecting. The gosom/google-maps-scraper open-source Docker image is the best free tool for this — it handles Playwright-based scraping, grid coverage, and anti-detection. We need a local orchestration layer that a non-developer can operate from Windows PowerShell.

## Decision

Wrap the Docker image in a PowerShell pipeline with four modules:

1. **Config** — reads bounding boxes from a static JSON file (manually configured via bboxfinder.com)
2. **Query Manager** — validates queries, manages state machine (Pending/Running/Completed) with disk persistence for crash recovery
3. **Scraper Runner** — builds and executes the `docker run` command
4. **Orchestrator** — wires the pipeline end-to-end

All pending queries are written to the input file and Docker runs once. State transitions happen before/after the Docker execution, not per-query.

## Consequences

- **Positive:** No geocoding API costs — coordinates are manual
- **Positive:** Resume/crash recovery is built from day one via state file
- **Positive:** No paid proxies required — the gosom image runs headless Playwright via free Docker
- **Negative:** PowerShell single-element array unwrapping requires defensive `@()` and comma-operator patterns
- **Negative:** Manual bounding box setup adds friction when switching cities
