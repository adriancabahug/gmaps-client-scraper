function Test-DockerInstalled {
    try {
        $null = Get-Command docker -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Test-DockerImage {
    $result = Invoke-Expression "docker images -q gosom/google-maps-scraper 2>`$null"
    return [bool]$result
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
        [Parameter(Mandatory)][string]$Query,
        [Parameter(Mandatory)][double[]]$BBox,
        [double]$CellSize = 2.0,
        [int]$Depth = 1,
        [switch]$Email,
        [string]$OutputDir = "gmaps-output"
    )

    $bboxStr = "$($BBox[0]),$($BBox[1]),$($BBox[2]),$($BBox[3])"

    $cmd = "docker run --rm -v gmaps-playwright-cache:/opt"
    $cmd += " -v `"`$PWD/$OutputDir`":/out"
    $cmd += " gosom/google-maps-scraper"
    $cmd += " -input /queries.txt"
    $cmd += " -results /out/results.json -json"
    $cmd += " -depth $Depth"
    $cmd += " -grid-bbox `"$bboxStr`""
    $cmd += " -grid-cell $CellSize"
    if ($Email) { $cmd += " -email" }
    $cmd += " -exit-on-inactivity 3m"

    $cmd
}
