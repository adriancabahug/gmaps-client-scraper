function Import-RawResults {
    param([Parameter(Mandatory)][string]$Path)

    Get-Content -Path $Path -Raw | ConvertFrom-Json
}

function Export-CleanResults {
    param(
        [Parameter(Mandatory)]$Results,
        [Parameter(Mandatory)][string]$JsonPath,
        [Parameter(Mandatory)][string]$CsvPath
    )

    $Results | ConvertTo-Json -Depth 4 | Set-Content -Path $JsonPath -Force
    $Results | Export-Csv -Path $CsvPath -NoTypeInformation -Force
}

function Filter-HasPhone {
    param([Parameter(Mandatory)]$Results)

    $filtered = [System.Collections.ArrayList]@()
    foreach ($item in $Results) {
        $phone = $item.phone
        if ($phone -and $phone -ne "") {
            [void]$filtered.Add($item)
        }
    }
    , $filtered.ToArray()
}

function Remove-Duplicates {
    param([Parameter(Mandatory)]$Results)

    $seen = @{}
    $deduped = [System.Collections.ArrayList]@()
    foreach ($item in $Results) {
        $id = $item.place_id
        if ($id -and -not $seen.ContainsKey($id)) {
            $seen[$id] = $true
            [void]$deduped.Add($item)
        }
    }
    , $deduped.ToArray()
}
