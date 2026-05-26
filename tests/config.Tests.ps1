$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here/../src/config.ps1"

Describe "Get-LocationBBox" {
    It "returns bounding box for a known city" {
        $configFile = [System.IO.Path]::GetTempFileName()
        @"
{
  "locations": {
    "dallas": {
      "bbox": [32.6, -96.85, 32.9, -96.65]
    }
  }
}
"@ | Set-Content -Path $configFile

        $bbox = Get-LocationBBox -City "dallas" -ConfigPath $configFile

        $bbox.Count | Should Be 4
        $bbox[0] | Should Be 32.6
        $bbox[1] | Should Be -96.85
        $bbox[2] | Should Be 32.9
        $bbox[3] | Should Be -96.65

        Remove-Item -Path $configFile -Force
    }

    It "throws for unknown city" {
        $configFile = [System.IO.Path]::GetTempFileName()
        @"
{
  "locations": {}
}
"@ | Set-Content -Path $configFile

        { Get-LocationBBox -City "atlantis" -ConfigPath $configFile } | Should Throw

        Remove-Item -Path $configFile -Force
    }
}
