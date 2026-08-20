[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()
$checks = [System.Collections.Generic.List[object]]::new()

function Assert-Result {
    param([string]$Name, [bool]$Passed, [string]$Detail)
    $checks.Add([pscustomobject]@{ name = $Name; passed = $Passed; detail = $Detail })
    if (-not $Passed) { $failures.Add("$Name`: $Detail") }
}

$skillRoot = Join-Path $repoRoot '.agents\skills\ask-harness'
$skillPath = Join-Path $skillRoot 'SKILL.md'
$referencePath = Join-Path $skillRoot 'references\bootstrap-flow.md'
$agentsPath = Join-Path $repoRoot 'AGENTS.md'
$harnessPath = Join-Path $repoRoot 'HARNESS.md'
$versionPath = Join-Path $repoRoot 'HARNESS_VERSION'
$sourcePath = Join-Path $repoRoot 'harness-source.yaml'
$configPath = Join-Path $repoRoot 'harness.config.yaml'
$validatorPath = Join-Path $repoRoot 'checks\validate-harness.ps1'
$readmePath = Join-Path $repoRoot 'README.md'

Assert-Result 'project_local_skill' (Test-Path -LiteralPath $skillPath -PathType Leaf) $skillPath
Assert-Result 'project_local_skill_reference' (Test-Path -LiteralPath $referencePath -PathType Leaf) $referencePath
Assert-Result 'root_harness_entry' (Test-Path -LiteralPath $harnessPath -PathType Leaf) $harnessPath
Assert-Result 'template_version' (Test-Path -LiteralPath $versionPath -PathType Leaf) $versionPath
Assert-Result 'template_source' (Test-Path -LiteralPath $sourcePath -PathType Leaf) $sourcePath
Assert-Result 'no_root_skill_package' (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'SKILL.md'))) 'The skill must live under .agents/skills/ask-harness.'

$agentRules = if (Test-Path -LiteralPath $agentsPath) { Get-Content -Raw -LiteralPath $agentsPath } else { '' }
Assert-Result 'agents_routes_explicit_invocation' ($agentRules -match [regex]::Escape('$ask-harness') -and $agentRules -match [regex]::Escape('.agents/skills/ask-harness/SKILL.md')) 'AGENTS.md must route the explicit invocation to the project-local skill.'

$configText = if (Test-Path -LiteralPath $configPath) { Get-Content -Raw -LiteralPath $configPath } else { '' }
$validatorText = if (Test-Path -LiteralPath $validatorPath) { Get-Content -Raw -LiteralPath $validatorPath } else { '' }
$readmeText = if (Test-Path -LiteralPath $readmePath) { Get-Content -Raw -LiteralPath $readmePath } else { '' }
$coreText = $configText + "`n" + $validatorText + "`n" + $agentRules
Assert-Result 'core_has_no_codex_runtime' ($coreText -notmatch 'codex-app') 'Core configuration, validation, and agent rules must not bind a named host.'
Assert-Result 'readme_uses_template_project' ($readmeText -match 'Use this template' -and $readmeText -notmatch '\.codex\\skills') 'README must describe template-project usage, not global Codex installation.'

if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
    try {
        $source = Get-Content -Raw -LiteralPath $sourcePath | ConvertFrom-Json
        Assert-Result 'source_records_template_repository' ($source.template_repository -eq 'https://github.com/shaahy/development-harness') ([string]$source.template_repository)
    } catch {
        Assert-Result 'source_records_template_repository' $false $_.Exception.Message
    }
}

$valid = $failures.Count -eq 0
[pscustomobject]@{
    schema_version = '1.0.0'
    valid = $valid
    check_count = $checks.Count
    errors = $failures
    checks = $checks
} | ConvertTo-Json -Depth 8

if (-not $valid) { exit 1 }
