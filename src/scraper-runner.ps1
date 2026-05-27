function Test-DockerInstalled {
    try {
        $null = Get-Command docker -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Invoke-DockerImagesQuery {
    & docker images -q gosom/google-maps-scraper 2>$null
}

function Test-DockerImage {
    try {
        $imageId = Invoke-DockerImagesQuery
        return [bool](![string]::IsNullOrWhiteSpace($imageId))
    } catch {
        return $false
    }
}

function Invoke-DockerCommand {
    param([Parameter(Mandatory)][string]$Command)

    try {
        Invoke-Expression $Command
        if ($global:LASTEXITCODE -eq 0) { return 0 } else { return 1 }
    } catch {
        return 1
    }
}

function Get-DockerCommand {
    param(
        [Parameter(Mandatory)][double[]]$BBox,
        [double]$CellSize = 2.0,
        [int]$Depth = 1,
        [switch]$Email,
        [string]$OutputDir = "gmaps-output"
    )

    $bboxStr = "$($BBox[0]),$($BBox[1]),$($BBox[2]),$($BBox[3])"

    $Arguments = @(
        "docker run --rm"
        "-v gmaps-playwright-cache:/opt"
        "-v `"$($PWD):/workspace`""
        "-v `"$($PWD)/$($OutputDir):/out`""
        "gosom/google-maps-scraper"
        "-input /workspace/queries.txt"
        "-results /out/results.json"
        "-json"
        "-depth $Depth"
        "-grid-bbox `"$bboxStr`""
        "-grid-cell $CellSize"
        "-exit-on-inactivity 3m"
    )
    if ($Email) { $Arguments += "-email" }

    return ($Arguments -join " ")
}
