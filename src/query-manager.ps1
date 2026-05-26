function Get-QueryList {
    param([Parameter(Mandatory)][string]$Path)

    Get-Content -Path $Path |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" } |
        Select-Object -Unique
}

function New-QueryState {
    param([Parameter(Mandatory)][string[]]$Queries)

    $state = @{
        version     = 1
        lastUpdated = [DateTime]::UtcNow.ToString("o")
        queries     = @()
    }

    $state.queries = @($Queries | ForEach-Object {
        @{
            text   = $_
            status = "Pending"
            cell   = 1
        }
    })

    $state
}

function Mark-QueryStatus {
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][string]$Query,
        [Parameter(Mandatory)][ValidateSet('Pending', 'Running', 'Completed')][string]$Status
    )

    foreach ($q in $State.queries) {
        if ($q.text -eq $Query) {
            $q.status = $Status
            break
        }
    }

    $State.lastUpdated = [DateTime]::UtcNow.ToString("o")
    $State
}

function Write-QueryState {
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][string]$Path
    )

    $State | ConvertTo-Json -Depth 4 | Set-Content -Path $Path -Force
}

function Get-PendingQueries {
    param([Parameter(Mandatory)]$State)

    $results = [System.Collections.ArrayList]@()
    $State.queries | Where-Object { $_.status -eq "Pending" } | ForEach-Object {
        [void]$results.Add($_.text)
    }
    , $results.ToArray()
}

function Reset-StuckRunning {
    param([Parameter(Mandatory)]$State)

    foreach ($q in $State.queries) {
        if ($q.status -eq "Running") {
            $q.status = "Pending"
        }
    }
    $State.lastUpdated = [DateTime]::UtcNow.ToString("o")
    $State
}

function Read-QueryState {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -Path $Path)) {
        return $null
    }

    Get-Content -Path $Path -Raw | ConvertFrom-Json
}
