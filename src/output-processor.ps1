function Import-RawResults {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Warning "Raw results file not found at: $Path"
        return @()
    }

    $Objects = Get-Content -Path $Path | ForEach-Object {
        $Line = $_.Trim()
        if (-not [string]::IsNullOrWhiteSpace($Line)) {
            try {
                ConvertFrom-Json $Line
            } catch {
                Write-Warning "Skipping malformed JSON line: $Line"
            }
        }
    }

    @($Objects)
}

function Remove-Duplicates {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [PSCustomObject]$InputObject
    )

    Begin {
        $SeenIds = [System.Collections.Generic.HashSet[string]]::new()
    }

    Process {
        if ($null -ne $InputObject -and -not [string]::IsNullOrEmpty($InputObject.place_id)) {
            if ($SeenIds.Add($InputObject.place_id)) {
                $InputObject
            }
        }
    }
}

function Filter-HasPhone {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [PSCustomObject]$InputObject
    )

    Process {
        if ($null -ne $InputObject -and -not [string]::IsNullOrWhiteSpace($InputObject.phone)) {
            $InputObject
        }
    }
}

function Export-CsvResults {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [PSCustomObject]$InputObject,
        [Parameter(Mandatory)][string]$Path
    )

    Begin {
        $Collected = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    Process {
        if ($null -ne $InputObject) {
            $name = if ($InputObject.title) { $InputObject.title } else { $InputObject.name }
            $Prospect = [PSCustomObject]@{
                Name    = $name
                Phone   = $InputObject.phone
                Address = $InputObject.address
                Rating  = $InputObject.rating
                Website = $InputObject.website
            }
            $Collected.Add($Prospect)
        }
    }

    End {
        if ($Collected.Count -gt 0) {
            $Dir = Split-Path $Path
            if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
            $Collected | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8 -Force
            Write-Host "Exported $($Collected.Count) prospects to $Path"
        } else {
            Write-Warning "No valid prospects collected to export."
        }
    }
}
