[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$errors = [System.Collections.Generic.List[string]]::new()
$checks = [System.Collections.Generic.List[object]]::new()

function Assert-Check {
    param([string]$Name, [bool]$Condition, [string]$Detail)
    $checks.Add([pscustomobject]@{ name = $Name; passed = $Condition; detail = $Detail })
    if (-not $Condition) { $errors.Add("$Name`: $Detail") }
}

$requiredFiles = @(
    'README.md','AGENTS.md','harness.config.yaml','workflow.yaml',
    'roles/orchestrator.md','roles/planner.md','roles/ui-preparer.md','roles/implementer.md','roles/tester.md','roles/debugger.md','roles/reviewer.md',
    'contracts/execution-input.schema.yaml','contracts/intake-result.schema.yaml','contracts/plan-result.schema.yaml','contracts/task-brief.schema.yaml','contracts/task-result.schema.yaml','contracts/defect.schema.yaml','contracts/review-result.schema.yaml',
    'templates/progress.md','templates/decision-ledger.md','templates/plan-evidence.md','templates/implementation-evidence.md','templates/final-acceptance-package.md',
    'checks/intake-check.ps1','checks/readiness-check.ps1','checks/resolve-next-action.ps1','examples/simulated-project/scenario.json','examples/simulated-project/execution-input.example.json'
)

foreach ($relative in $requiredFiles) {
    $path = Join-Path $root $relative
    Assert-Check "file:$relative" (Test-Path -LiteralPath $path -PathType Leaf) $path
}

$config = Get-Content -LiteralPath (Join-Path $root 'harness.config.yaml') -Raw | ConvertFrom-Json
$workflow = Get-Content -LiteralPath (Join-Path $root 'workflow.yaml') -Raw | ConvertFrom-Json

Assert-Check 'runtime_codex_app' ($config.runtime -eq 'codex-app') $config.runtime
Assert-Check 'single_writer' ($config.concurrency.max_concurrent_writers -eq 1) ([string]$config.concurrency.max_concurrent_writers)
Assert-Check 'debug_breaker_three' ($config.limits.max_debug_attempts_per_root_cause -eq 3) ([string]$config.limits.max_debug_attempts_per_root_cause)
Assert-Check 'review_breaker_five' ($config.limits.max_review_fix_rounds_per_task -eq 5) ([string]$config.limits.max_review_fix_rounds_per_task)
Assert-Check 'ui_review_breaker_three' ($config.limits.max_ui_review_rounds -eq 3) ([string]$config.limits.max_ui_review_rounds)
Assert-Check 'plan_review_breaker_three' ($config.limits.max_plan_review_rounds -eq 3) ([string]$config.limits.max_plan_review_rounds)
Assert-Check 'auto_ui_enabled' ($config.automation.auto_generate_missing_ui_baseline -eq $true) ([string]$config.automation.auto_generate_missing_ui_baseline)
Assert-Check 'auto_plan_enabled' ($config.automation.auto_generate_implementation_plan -eq $true -and $config.automation.auto_review_implementation_plan -eq $true) ($config.automation | ConvertTo-Json -Compress)
Assert-Check 'default_subagent_execution' ($config.automation.default_execution_mode -eq 'subagent-driven-development') $config.automation.default_execution_mode

$forbidden = @($config.git.forbidden_without_human_approval)
foreach ($operation in @('merge','push','deploy','publish','release')) {
    Assert-Check "forbidden:$operation" ($forbidden -contains $operation) ($forbidden -join ',')
}

$agentRules = Get-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Raw
Assert-Check 'external_actions_remain_gated' (($forbidden -contains 'merge') -and ($forbidden -contains 'push') -and ($forbidden -contains 'deploy')) 'Configuration must keep merge, push, and deploy gated.'
Assert-Check 'agents_requires_fresh_evidence' ($agentRules -match 'commit SHA' -and $agentRules -match 'Reviewer') 'AGENTS.md must require commit and independent review evidence.'
Assert-Check 'agents_prevents_test_tampering' ($agentRules -match 'Tester' -and $agentRules -match 'Debugger') 'AGENTS.md must separate test and debug roles.'
Assert-Check 'agents_starts_from_spec' ($agentRules -match 'matt_spec_only' -and $agentRules -match 'writing-plans') 'AGENTS.md must accept Matt Spec and auto-generate the plan.'
Assert-Check 'agents_auto_ui_fallback' (($agentRules -match 'UI Preparer') -and ($agentRules -match 'ui-ux-pro-max')) 'AGENTS.md must define automatic UI fallback.'

$inputContract = Get-Content -LiteralPath (Join-Path $root 'contracts/execution-input.schema.yaml') -Raw
Assert-Check 'input_has_dual_profiles' ($inputContract -match 'matt_spec_only' -and $inputContract -match 'matt_plus_uiux') 'Both input profiles are required.'
Assert-Check 'input_does_not_require_approved_plan' (-not ($inputContract -match 'approved_plan')) 'A human-approved plan must not be an intake requirement.'
Assert-Check 'workflow_starts_at_intake' ($workflow.initial_state -eq 'READY_FOR_INTAKE') $workflow.initial_state
Assert-Check 'workflow_has_plan_loop' (($workflow.transitions.event -contains 'PLAN_REVIEW_FAILED') -and ($workflow.transitions.event -contains 'PLAN_REVIEW_PASSED')) 'Automatic plan review loop is required.'

$exactKeys = @{}
foreach ($transition in $workflow.transitions) {
    $key = "$($transition.from)|$($transition.event)"
    if ($exactKeys.ContainsKey($key)) {
        $errors.Add("duplicate transition: $key")
    } else {
        $exactKeys[$key] = $true
    }
}
Assert-Check 'workflow_transition_keys_unique' (-not ($errors | Where-Object { $_ -like 'duplicate transition:*' })) 'Duplicate from/event transitions are not allowed.'
$terminalWithOutgoing = @($workflow.terminal_states | Where-Object { $terminal = $_; $workflow.transitions | Where-Object { $_.from -eq $terminal } })
Assert-Check 'terminal_states_have_no_outgoing_transition' ($terminalWithOutgoing.Count -eq 0) ($terminalWithOutgoing -join ',')

$contracts = Get-ChildItem -LiteralPath (Join-Path $root 'contracts') -File -Filter '*.schema.yaml'
foreach ($contract in $contracts) {
    try {
        $parsed = Get-Content -LiteralPath $contract.FullName -Raw | ConvertFrom-Json
        Assert-Check "schema:$($contract.Name)" ($parsed.'$schema' -eq 'https://json-schema.org/draft/2020-12/schema') $parsed.'$schema'
    } catch {
        Assert-Check "schema:$($contract.Name)" $false $_.Exception.Message
    }
}

$scenarioPath = Join-Path $root 'examples/simulated-project/scenario.json'
if (Test-Path -LiteralPath $scenarioPath -PathType Leaf) {
    $scenarios = Get-Content -LiteralPath $scenarioPath -Raw | ConvertFrom-Json
    foreach ($scenario in $scenarios.cases) {
        try {
            $raw = & (Join-Path $PSScriptRoot 'resolve-next-action.ps1') -State $scenario.from -Event $scenario.event -WorkflowPath (Join-Path $root 'workflow.yaml')
            $resolved = $raw | ConvertFrom-Json
            $passed = $resolved.resolved -eq $true -and $resolved.to -eq $scenario.expected_to -and $resolved.action -eq $scenario.expected_action
            Assert-Check "scenario:$($scenario.name)" $passed "$($resolved.to) / $($resolved.action)"
        } catch {
            Assert-Check "scenario:$($scenario.name)" $false $_.Exception.Message
        }
    }
}

$valid = $errors.Count -eq 0
[pscustomobject]@{
    schema_version = '1.1.0'
    valid = $valid
    root = $root
    check_count = $checks.Count
    errors = $errors
    checks = $checks
} | ConvertTo-Json -Depth 8

if (-not $valid) { exit 1 }
