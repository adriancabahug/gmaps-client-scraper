function Import-RawResults {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Warning "Raw results file not found at: $Path"
        return @()
    }

    $Content = Get-Content -Raw -Path $Path
    if ([string]::IsNullOrWhiteSpace($Content)) {
        return @()
    }

    ConvertFrom-Json $Content
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
