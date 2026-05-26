$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\..\src\output-processor.ps1"

Describe "Import-RawResults" {
    It "reads valid JSON and returns objects" {
        $results = Import-RawResults -Path "$here\fixtures\sample-results.json"

        $results.Count | Should Be 6
        $results[0].title | Should Be "Dallas Roofing Pros"
        $results[0].phone | Should Be "(214) 555-0101"
    }
}

Describe "Filter-HasPhone" {
    It "keeps entries with a phone number" {
        $results = Import-RawResults -Path "$here\fixtures\sample-results.json"
        $deduped = Remove-Duplicates -Results $results

        $filtered = Filter-HasPhone -Results $deduped

        $filtered.Count | Should Be 3
        $filtered[0].title | Should Be "Dallas Roofing Pros"
        $filtered[1].title | Should Be "Big D Roofers"
        $filtered[2].title | Should Be "Apex Roofing Solutions"
    }

    It "removes entries with empty or null phone" {
        $results = Import-RawResults -Path "$here\fixtures\sample-results.json"
        $deduped = Remove-Duplicates -Results $results

        $filtered = Filter-HasPhone -Results $deduped

        $hasEmptyPhone = $filtered | Where-Object { -not $_.phone }
        $hasEmptyPhone.Count | Should Be 0
    }
}

Describe "Export-CleanResults" {
    It "writes JSON and CSV files with clean data" {
        $results = Import-RawResults -Path "$here\fixtures\sample-results.json"
        $deduped = Remove-Duplicates -Results $results
        $filtered = Filter-HasPhone -Results $deduped

        $jsonFile = [System.IO.Path]::GetTempFileName()
        $csvFile = [System.IO.Path]::GetTempFileName()

        Export-CleanResults -Results $filtered -JsonPath $jsonFile -CsvPath $csvFile

        $jsonContent = Get-Content -Path $jsonFile -Raw | ConvertFrom-Json
        $jsonContent.Count | Should Be 3

        $csvContent = Import-Csv -Path $csvFile
        $csvContent.Count | Should Be 3
        $csvContent[0].title | Should Be "Dallas Roofing Pros"

        Remove-Item -Path $jsonFile -Force
        Remove-Item -Path $csvFile -Force
    }

    It "writes CSV with correct column headers" {
        $results = @(
            [PSCustomObject]@{ title = "Test Co"; place_id = "1"; phone = "555-0100"; website = "test.com" }
        )

        $jsonFile = [System.IO.Path]::GetTempFileName()
        $csvFile = [System.IO.Path]::GetTempFileName()

        Export-CleanResults -Results $results -JsonPath $jsonFile -CsvPath $csvFile

        $csv = Import-Csv -Path $csvFile
        $csv[0].title | Should Be "Test Co"
        $csv[0].phone | Should Be "555-0100"

        Remove-Item -Path $jsonFile -Force
        Remove-Item -Path $csvFile -Force
    }
}

Describe "Remove-Duplicates" {
    It "deduplicates by place_id, keeping first occurrence" {
        $results = Import-RawResults -Path "$here\fixtures\sample-results.json"

        $deduped = Remove-Duplicates -Results $results

        $deduped.Count | Should Be 5
        $deduped[0].place_id | Should Be "ChIJ1"
        $deduped[0].title | Should Be "Dallas Roofing Pros"
    }

    It "returns same list when no duplicates exist" {
        $unique = @(
            [PSCustomObject]@{ title = "A"; place_id = "1" }
            [PSCustomObject]@{ title = "B"; place_id = "2" }
        )

        $deduped = Remove-Duplicates -Results $unique

        $deduped.Count | Should Be 2
    }
}
