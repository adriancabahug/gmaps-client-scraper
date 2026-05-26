$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\..\src\scraper-runner.ps1"

Describe "Test-DockerInstalled" {
    It "returns true when docker command is available" {
        Mock Get-Command { return @{ Source = "C:\docker.exe" } } -ParameterFilter { $Name -eq "docker" }

        $result = Test-DockerInstalled
        $result | Should Be $true
    }

    It "returns false when docker command is not available" {
        Mock Get-Command { throw "not found" } -ParameterFilter { $Name -eq "docker" }

        $result = Test-DockerInstalled
        $result | Should Be $false
    }
}

Describe "Test-DockerImage" {
    It "returns true when image exists locally" {
        Mock Invoke-Expression { return "abcdef123456" } -ParameterFilter { $Command -like "*docker images*" }

        $result = Test-DockerImage
        $result | Should Be $true
    }

    It "returns false when image is not pulled" {
        Mock Invoke-Expression { return $null } -ParameterFilter { $Command -like "*docker images*" }

        $result = Test-DockerImage
        $result | Should Be $false
    }
}

Describe "Invoke-DockerCommand" {
    It "returns exit code 0 on success" {
        Mock Invoke-Expression { $global:LASTEXITCODE = 0 } -ParameterFilter { $Command -eq "docker run --rm test" }

        $exitCode = Invoke-DockerCommand "docker run --rm test"
        $exitCode | Should Be 0
    }

    It "returns exit code 1 on failure" {
        Mock Invoke-Expression { throw "error" } -ParameterFilter { $Command -eq "docker run --rm bad" }

        $exitCode = Invoke-DockerCommand "docker run --rm bad"
        $exitCode | Should Be 1
    }
}

Describe "Get-DockerCommand" {
    It "builds the docker run command with all parameters" {
        $cmd = Get-DockerCommand -Query "Roofers Dallas" -BBox @(32.6, -96.85, 32.9, -96.65) -CellSize 2.0 -Depth 1 -Email

        $cmd | Should Match "^docker run"
        $cmd | Should Match "--rm"
        $cmd | Should Match "gosom/google-maps-scraper"
        $cmd | Should Match "-depth 1"
        $cmd | Should Match '-grid-bbox "32.6,-96.85,32.9,-96.65"'
        $cmd | Should Match "-grid-cell 2"
        $cmd | Should Match "-email"
        $cmd | Should Match "-json"
        $cmd | Should Match "-exit-on-inactivity 3m"
    }

    It "omits email flag when not requested" {
        $cmd = Get-DockerCommand -Query "Roofers Dallas" -BBox @(32.6, -96.85, 32.9, -96.65)

        $cmd | Should Not Match "-email"
    }

    It "includes email flag when requested" {
        $cmd = Get-DockerCommand -Query "Roofers Dallas" -BBox @(32.6, -96.85, 32.9, -96.65) -Email

        $cmd | Should Match "-email"
    }
}
