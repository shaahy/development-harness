[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$State,

    [Parameter(Mandatory = $true)]
    [string]$Event,

    [string]$WorkflowPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'workflow.yaml')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $WorkflowPath -PathType Leaf)) {
    throw "Workflow file not found: $WorkflowPath"
}

$workflow = Get-Content -LiteralPath $WorkflowPath -Raw | ConvertFrom-Json
$matches = @($workflow.transitions | Where-Object {
    ($_.from -eq $State -or $_.from -eq '*') -and $_.event -eq $Event
})

if ($matches.Count -eq 0) {
    [pscustomobject]@{
        resolved = $false
        state = $State
        event = $Event
        error = 'NO_VALID_TRANSITION'
    } | ConvertTo-Json -Depth 5
    exit 3
}

$exact = @($matches | Where-Object { $_.from -eq $State })
$selected = if ($exact.Count -eq 1) { $exact[0] } elseif ($exact.Count -gt 1) {
    throw "Ambiguous exact transition for state '$State' and event '$Event'."
} elseif ($matches.Count -eq 1) {
    $matches[0]
} else {
    throw "Ambiguous wildcard transition for state '$State' and event '$Event'."
}

[pscustomobject]@{
    resolved = $true
    from = $State
    event = $Event
    to = $selected.to
    action = $selected.action
} | ConvertTo-Json -Depth 5
