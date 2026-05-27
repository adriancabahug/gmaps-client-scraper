$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here/../src/output-processor.ps1"

Describe "Import-RawResults" {
    It "reads valid JSON and returns objects" {
        $results = Import-RawResults -Path "$here/fixtures/sample-results.json"

        $results.Count | Should Be 6
        $results[0].title | Should Be "Dallas Roofing Pros"
        $results[0].phone | Should Be "(214) 555-0101"
    }
}

Describe "Remove-Duplicates" {
    It "deduplicates by place_id, keeping first occurrence" {
        $results = Import-RawResults -Path "$here/fixtures/sample-results.json"

        $deduped = $results | Remove-Duplicates

        $deduped.Count | Should Be 5
        $deduped[0].place_id | Should Be "ChIJ1"
        $deduped[0].title | Should Be "Dallas Roofing Pros"
    }

    It "returns same list when no duplicates exist" {
        $unique = @(
            [PSCustomObject]@{ title = "A"; place_id = "1" }
            [PSCustomObject]@{ title = "B"; place_id = "2" }
        )

        $deduped = $unique | Remove-Duplicates

        $deduped.Count | Should Be 2
    }
}

Describe "Filter-HasPhone" {
    It "keeps entries with a phone number" {
        $results = Import-RawResults -Path "$here/fixtures/sample-results.json"

        $filtered = $results | Remove-Duplicates | Filter-HasPhone

        $filtered.Count | Should Be 3
        $filtered[0].title | Should Be "Dallas Roofing Pros"
        $filtered[1].title | Should Be "Big D Roofers"
        $filtered[2].title | Should Be "Apex Roofing Solutions"
    }

    It "removes entries with empty or null phone" {
        $results = Import-RawResults -Path "$here/fixtures/sample-results.json"

        $filtered = $results | Remove-Duplicates | Filter-HasPhone

        $hasEmptyPhone = $filtered | Where-Object { -not $_.phone }
        $hasEmptyPhone.Count | Should Be 0
    }
}

Describe "Export-CsvResults" {
    It "writes CSV with correct columns" {
        $results = Import-RawResults -Path "$here/fixtures/sample-results.json"

        $csvFile = [System.IO.Path]::GetTempFileName()

        $results | Remove-Duplicates | Filter-HasPhone | Export-CsvResults -Path $csvFile

        $csv = Import-Csv -Path $csvFile
        $csv.Count | Should Be 3
        $csv[0].Name | Should Be "Dallas Roofing Pros"
        $csv[0].Phone | Should Be "(214) 555-0101"

        Remove-Item -Path $csvFile -Force
    }
}
