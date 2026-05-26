function Get-LocationBBox {
    param(
        [Parameter(Mandatory)][string]$City,
        [string]$ConfigPath = "config.json"
    )

    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

    if (-not $config.locations.$City) {
        throw "Unknown city: $City"
    }

    $config.locations.$City.bbox
}
