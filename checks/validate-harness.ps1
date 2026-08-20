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
    'AGENTS.md','HARNESS.md','HARNESS_VERSION','harness-source.yaml','harness.config.yaml','workflow.yaml',
    '.agents/skills/ask-harness/SKILL.md','.agents/skills/ask-harness/references/bootstrap-flow.md',
    'roles/orchestrator.md','roles/planner.md','roles/ui-preparer.md','roles/implementer.md','roles/tester.md','roles/debugger.md','roles/reviewer.md',
    'contracts/bootstrap-result.schema.yaml','contracts/execution-input.schema.yaml','contracts/intake-result.schema.yaml','contracts/plan-result.schema.yaml','contracts/task-brief.schema.yaml','contracts/task-result.schema.yaml','contracts/defect.schema.yaml','contracts/review-result.schema.yaml',
    'templates/bootstrap-report.md','templates/progress.md','templates/decision-ledger.md','templates/plan-evidence.md','templates/implementation-evidence.md','templates/final-acceptance-package.md',
    'scripts/install-harness.ps1','scripts/initialize-project.ps1','scripts/new-execution-input.ps1',
    'checks/bootstrap-check.ps1','checks/intake-check.ps1','checks/readiness-check.ps1','checks/resolve-next-action.ps1','examples/simulated-project/scenario.json','examples/simulated-project/execution-input.example.json'
)

foreach ($relative in $requiredFiles) {
    $path = Join-Path $root $relative
    Assert-Check "file:$relative" (Test-Path -LiteralPath $path -PathType Leaf) $path
}

$config = Get-Content -LiteralPath (Join-Path $root 'harness.config.yaml') -Raw | ConvertFrom-Json
$workflow = Get-Content -LiteralPath (Join-Path $root 'workflow.yaml') -Raw | ConvertFrom-Json
$source = Get-Content -LiteralPath (Join-Path $root 'harness-source.yaml') -Raw | ConvertFrom-Json
$version = (Get-Content -LiteralPath (Join-Path $root 'HARNESS_VERSION') -Raw).Trim()

Assert-Check 'template_source' ($source.template_repository -eq 'https://github.com/shaahy/development-harness') ([string]$source.template_repository)
Assert-Check 'template_version_consistent' ($version -eq $source.harness_version -and $version -eq $config.schema_version) "$version / $($source.harness_version) / $($config.schema_version)"
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

$agentRules = [IO.File]::ReadAllText((Join-Path $root 'AGENTS.md'), [Text.Encoding]::UTF8)
$harnessRules = [IO.File]::ReadAllText((Join-Path $root 'HARNESS.md'), [Text.Encoding]::UTF8)
$skillRules = [IO.File]::ReadAllText((Join-Path $root '.agents/skills/ask-harness/SKILL.md'), [Text.Encoding]::UTF8)
Assert-Check 'project_local_skill_route' ($agentRules -match [regex]::Escape('$ask-harness') -and $agentRules -match [regex]::Escape('.agents/skills/ask-harness/SKILL.md')) 'AGENTS.md 必须把 $ask-harness 路由到项目内技能。'
Assert-Check 'platform_independent_core' ($config.PSObject.Properties.Name -notcontains 'runtime') 'Harness 核心配置不得声明特定宿主运行时。'
Assert-Check 'skill_requires_real_multi_agent' ($skillRules -match '具备完整能力的多 Agent 开发环境' -and $skillRules -match '不要识别宿主' -and $skillRules -match '降级执行模式') '项目技能必须假设完整多 Agent 能力，不得检测宿主或设计降级方案。'
Assert-Check 'user_facing_language_chinese' ($agentRules -match '简体中文' -and $harnessRules -match '简体中文' -and $skillRules -match '简体中文') 'AGENTS.md、HARNESS.md 和 Ask Harness 技能必须统一规定简体中文交互。'
Assert-Check 'external_actions_remain_gated' (($forbidden -contains 'merge') -and ($forbidden -contains 'push') -and ($forbidden -contains 'deploy')) '配置必须继续限制 merge、push 和 deploy。'
Assert-Check 'agents_requires_fresh_evidence' ($agentRules -match 'commit SHA' -and $agentRules -match 'Reviewer') 'AGENTS.md 必须要求提交和独立审查证据。'
Assert-Check 'agents_prevents_test_tampering' ($agentRules -match 'Tester' -and $agentRules -match 'Debugger') 'AGENTS.md 必须分离测试与调试角色。'
Assert-Check 'agents_starts_from_spec' ($agentRules -match 'matt_spec_only' -and $agentRules -match 'writing-plans') 'AGENTS.md 必须接受 Matt Spec 并自动生成计划。'
Assert-Check 'agents_auto_ui_fallback' (($agentRules -match 'UI Preparer') -and ($agentRules -match 'ui-ux-pro-max')) 'AGENTS.md 必须定义自动 UI 补齐机制。'

$inputContract = Get-Content -LiteralPath (Join-Path $root 'contracts/execution-input.schema.yaml') -Raw
Assert-Check 'input_has_dual_profiles' ($inputContract -match 'matt_spec_only' -and $inputContract -match 'matt_plus_uiux') '必须支持两种输入档案。'
Assert-Check 'input_does_not_require_approved_plan' (-not ($inputContract -match 'approved_plan')) 'Intake 不得要求人工批准计划。'
Assert-Check 'input_separates_start_authorization' ($inputContract -match 'technical_design_approved_by_human' -and $inputContract -match '"execution_authorized"\s*:\s*\{"type":"boolean"\}') 'Bootstrap 必须区分技术批准与最终执行授权。'
Assert-Check 'workflow_starts_at_intake' ($workflow.initial_state -eq 'READY_FOR_INTAKE') $workflow.initial_state
Assert-Check 'workflow_has_plan_loop' (($workflow.transitions.event -contains 'PLAN_REVIEW_FAILED') -and ($workflow.transitions.event -contains 'PLAN_REVIEW_PASSED')) '必须存在自动计划审查循环。'

$exactKeys = @{}
foreach ($transition in $workflow.transitions) {
    $key = "$($transition.from)|$($transition.event)"
    if ($exactKeys.ContainsKey($key)) {
        $errors.Add("重复状态转换：$key")
    } else {
        $exactKeys[$key] = $true
    }
}
Assert-Check 'workflow_transition_keys_unique' (-not ($errors | Where-Object { $_ -like '重复状态转换：*' })) '不允许重复的 from/event 状态转换。'
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
    schema_version = '1.2.0'
    valid = $valid
    root = $root
    check_count = $checks.Count
    errors = $errors
    checks = $checks
} | ConvertTo-Json -Depth 8

if (-not $valid) { exit 1 }
