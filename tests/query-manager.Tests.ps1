$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here/../src/query-manager.ps1"

Describe "Get-QueryList" {
    Context "input validation" {
        It "strips whitespace, removes blank lines, and deduplicates" {
            $tempFile = [System.IO.Path]::GetTempFileName()
            @"
  Residential Roofing Contractors in Dallas, Texas
Dental Clinics in Austin, Texas

   Residential Roofing Contractors in Dallas, Texas
Plumbers in Houston, Texas

"@ | Set-Content -Path $tempFile

            $result = Get-QueryList -Path $tempFile

            $result.Count | Should Be 3
            $result[0] | Should Be "Residential Roofing Contractors in Dallas, Texas"
            $result[1] | Should Be "Dental Clinics in Austin, Texas"
            $result[2] | Should Be "Plumbers in Houston, Texas"

            Remove-Item -Path $tempFile -Force
        }
    }
}

Describe "State lifecycle" {
    Context "New-QueryState" {
        It "initializes all queries as Pending" {
            $queries = @("Roofers Dallas", "Dentists Austin")
            $state = New-QueryState -Queries $queries

            $state.version | Should Be 1
            $state.queries.Count | Should Be 2
            $state.queries[0].text | Should Be "Roofers Dallas"
            $state.queries[0].status | Should Be "Pending"
            $state.queries[1].text | Should Be "Dentists Austin"
            $state.queries[1].status | Should Be "Pending"
            $state.lastUpdated -ne $null | Should Be $true
        }
    }

    Context "Mark-QueryStatus" {
        It "transitions a query to Running" {
            $queries = @("Roofers Dallas", "Dentists Austin")
            $state = New-QueryState -Queries $queries

            $state = Mark-QueryStatus -State $state -Query "Roofers Dallas" -Status "Running"

            $state.queries[0].status | Should Be "Running"
            $state.queries[1].status | Should Be "Pending"
        }

        It "transitions a query to Completed" {
            $queries = @("Roofers Dallas")
            $state = New-QueryState -Queries $queries

            $state = Mark-QueryStatus -State $state -Query "Roofers Dallas" -Status "Completed"

            $state.queries[0].status | Should Be "Completed"
        }
    }

    Context "Write and Read round-trip" {
        It "persists and restores state correctly" {
            $queries = @("Roofers Dallas", "Dentists Austin")
            $state = New-QueryState -Queries $queries
            $state = Mark-QueryStatus -State $state -Query "Roofers Dallas" -Status "Running"

            $stateFile = [System.IO.Path]::GetTempFileName()
            Write-QueryState -State $state -Path $stateFile

            $restored = Read-QueryState -Path $stateFile

            $restored.version | Should Be 1
            $restored.queries.Count | Should Be 2
            $restored.queries[0].text | Should Be "Roofers Dallas"
            $restored.queries[0].status | Should Be "Running"
            $restored.queries[1].text | Should Be "Dentists Austin"
            $restored.queries[1].status | Should Be "Pending"

            Remove-Item -Path $stateFile -Force
        }
    }
}

Describe "Reset-StuckRunning" {
    It "resets Running queries to Pending" {
        $queries = @("Roofers Dallas", "Dentists Austin", "Plumbers Houston")
        $state = New-QueryState -Queries $queries
        $state = Mark-QueryStatus -State $state -Query "Roofers Dallas" -Status "Running"
        $state = Mark-QueryStatus -State $state -Query "Dentists Austin" -Status "Completed"

        $state = Reset-StuckRunning -State $state

        $state.queries[0].status | Should Be "Pending"
        $state.queries[1].status | Should Be "Completed"
        $state.queries[2].status | Should Be "Pending"
    }

    It "does nothing when no queries are Running" {
        $queries = @("Roofers Dallas", "Dentists Austin")
        $state = New-QueryState -Queries $queries
        $state = Mark-QueryStatus -State $state -Query "Roofers Dallas" -Status "Completed"

        $state = Reset-StuckRunning -State $state

        $state.queries[0].status | Should Be "Completed"
        $state.queries[1].status | Should Be "Pending"
    }
}

Describe "Get-PendingQueries" {
    It "returns all queries when none are completed" {
        $queries = @("Roofers Dallas", "Dentists Austin", "Plumbers Houston")
        $state = New-QueryState -Queries $queries

        $pending = Get-PendingQueries -State $state

        $pending.Count | Should Be 3
    }

    It "excludes completed queries" {
        $queries = @("Roofers Dallas", "Dentists Austin")
        $state = New-QueryState -Queries $queries
        $state = Mark-QueryStatus -State $state -Query "Roofers Dallas" -Status "Completed"

        $pending = Get-PendingQueries -State $state

        $pending.Count | Should Be 1
        $pending[0] | Should Be "Dentists Austin"
    }

    It "excludes running queries" {
        $queries = @("Roofers Dallas", "Dentists Austin")
        $state = New-QueryState -Queries $queries
        $state = Mark-QueryStatus -State $state -Query "Roofers Dallas" -Status "Running"

        $pending = Get-PendingQueries -State $state

        $pending.Count | Should Be 1
        $pending[0] | Should Be "Dentists Austin"
    }

    It "returns empty array when all queries are completed" {
        $queries = @("Roofers Dallas")
        $state = New-QueryState -Queries $queries
        $state = Mark-QueryStatus -State $state -Query "Roofers Dallas" -Status "Completed"

        $pending = Get-PendingQueries -State $state

        $pending.Count | Should Be 0
    }
}
