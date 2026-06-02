# Google Maps Scraper

Scrapes Google Maps business listings (name, phone, email, website, rating, review count, address) for cold-calling prospecting using the [gosom/google-maps-scraper](https://github.com/gosom/google-maps-scraper) Docker image.

## How to Use

1. Go to the repository on GitHub.com
2. Click **Actions** → **Cloud Outbound Scraper** → **Run workflow**
3. Wait for the run to finish (green checkmark)
4. Run `git pull` — results are in `gmaps-output/prospects.csv`

## Customizing the Search

Edit the query or bounding box in `.github/workflows/scrape.yml` under the **Execute Scraper Pipeline** step. Get bounding box coordinates from [bboxfinder.com](http://bboxfinder.com).

## Files

| File | Purpose |
|---|---|
| `run-scraper.ps1` | Single-file scraper: writes query → runs Docker → processes NDJSON → exports CSV |
| `.github/workflows/scrape.yml` | GitHub Actions workflow — manual trigger, ubuntu-latest, commits output back |
