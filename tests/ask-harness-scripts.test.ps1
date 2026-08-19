[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("ask-harness-test-" + [guid]::NewGuid().ToString('N'))
$failures = [System.Collections.Generic.List[string]]::new()
$checks = [System.Collections.Generic.List[object]]::new()

function Assert-Result {
    param([string]$Name, [bool]$Passed, [string]$Detail)
    $checks.Add([pscustomobject]@{ name=$Name; passed=$Passed; detail=$Detail })
    if (-not $Passed) { $failures.Add("$Name`: $Detail") }
}

function Invoke-ScriptJson {
    param([string]$ScriptPath, [string[]]$Arguments)
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments
    $exitCode = $LASTEXITCODE
    $parsed = $null
    if ($output) { $parsed = ($output -join [Environment]::NewLine) | ConvertFrom-Json }
    [pscustomobject]@{ exit_code=$exitCode; json=$parsed; raw=($output -join [Environment]::NewLine) }
}

function Write-TestFile {
    param([string]$Path,[string]$Value)
    [IO.File]::WriteAllText($Path,$Value + "`n",[Text.UTF8Encoding]::new($false))
}

try {
    $fresh = Join-Path $testRoot 'fresh-project'
    $conflict = Join-Path $testRoot 'conflict-project'
    $null = New-Item -ItemType Directory -Path (Join-Path $fresh '.scratch\feature') -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $fresh 'docs\architecture') -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $fresh 'docs\ui-ux\feature') -Force
    $null = New-Item -ItemType Directory -Path $conflict -Force

    Write-TestFile (Join-Path $fresh 'CONTEXT.md') '# Domain language'
    Write-TestFile (Join-Path $fresh '.scratch\feature\spec.md') '# Approved Spec'
    Write-TestFile (Join-Path $fresh 'docs\architecture\ADR-001.md') '# Approved technical baseline'
    Write-TestFile (Join-Path $fresh 'docs\ui-ux\feature\handoff.md') '# Handoff'
    Write-TestFile (Join-Path $fresh 'docs\ui-ux\feature\UI-CONTRACT.md') '# UI Contract'
    Write-TestFile (Join-Path $fresh 'docs\ui-ux\feature\tokens.json') '{"color":"green"}'
    Write-TestFile (Join-Path $fresh 'docs\ui-ux\feature\tokens.css') ':root{}'
    Write-TestFile (Join-Path $fresh 'docs\ui-ux\feature\components.md') '# Components'
    Write-TestFile (Join-Path $fresh 'docs\ui-ux\feature\states.md') '# States'
    Write-TestFile (Join-Path $conflict 'AGENTS.md') 'USER RULES MUST SURVIVE'

    $installScript = Join-Path $repoRoot 'scripts\install-harness.ps1'
    $gitScript = Join-Path $repoRoot 'scripts\initialize-project.ps1'
    $inputScript = Join-Path $repoRoot 'scripts\new-execution-input.ps1'
    $bootstrapScript = Join-Path $repoRoot 'checks\bootstrap-check.ps1'

    Assert-Result 'script_install_exists' (Test-Path -LiteralPath $installScript -PathType Leaf) $installScript
    Assert-Result 'script_git_exists' (Test-Path -LiteralPath $gitScript -PathType Leaf) $gitScript
    Assert-Result 'script_input_exists' (Test-Path -LiteralPath $inputScript -PathType Leaf) $inputScript
    Assert-Result 'script_bootstrap_exists' (Test-Path -LiteralPath $bootstrapScript -PathType Leaf) $bootstrapScript

    if ($failures.Count -eq 0) {
        $preview = Invoke-ScriptJson $installScript @('-TargetRoot',$fresh)
        Assert-Result 'install_preview_no_write' (-not (Test-Path -LiteralPath (Join-Path $fresh 'harness.config.yaml'))) $preview.raw
        Assert-Result 'install_preview_ready' ($preview.exit_code -eq 0 -and $preview.json.status -eq 'READY_TO_INSTALL') $preview.raw

        $installed = Invoke-ScriptJson $installScript @('-TargetRoot',$fresh,'-Apply')
        Assert-Result 'install_apply_pass' ($installed.exit_code -eq 0 -and $installed.json.status -eq 'INSTALLED') $installed.raw
        Assert-Result 'install_does_not_copy_git' (-not (Test-Path -LiteralPath (Join-Path $fresh '.git'))) 'Installer must not copy or initialize .git.'
        Assert-Result 'install_places_harness_doc' (Test-Path -LiteralPath (Join-Path $fresh 'HARNESS.md') -PathType Leaf) 'HARNESS.md missing.'
        $installedValidation = Invoke-ScriptJson (Join-Path $fresh 'checks\validate-harness.ps1') @()
        Assert-Result 'installed_harness_validates' ($installedValidation.exit_code -eq 0 -and $installedValidation.json.valid -eq $true) $installedValidation.raw
        $idempotentPreview = Invoke-ScriptJson $installScript @('-TargetRoot',$fresh)
        Assert-Result 'install_is_idempotent' ($idempotentPreview.exit_code -eq 0 -and $idempotentPreview.json.status -eq 'READY_TO_INSTALL' -and @($idempotentPreview.json.files).Count -eq 0) $idempotentPreview.raw

        $collisionResult = Invoke-ScriptJson $installScript @('-TargetRoot',$conflict,'-Apply')
        $preserved = (Get-Content -LiteralPath (Join-Path $conflict 'AGENTS.md') -Raw).Trim()
        Assert-Result 'collision_blocks_install' ($collisionResult.exit_code -ne 0 -and $collisionResult.json.status -eq 'BLOCKED_COLLISION') $collisionResult.raw
        Assert-Result 'collision_preserves_user_rules' ($preserved -eq 'USER RULES MUST SURVIVE') $preserved

        $gitPreview = Invoke-ScriptJson $gitScript @('-TargetRoot',$fresh)
        Assert-Result 'git_preview_no_write' (-not (Test-Path -LiteralPath (Join-Path $fresh '.git'))) $gitPreview.raw
        $gitApplied = Invoke-ScriptJson $gitScript @('-TargetRoot',$fresh,'-Apply')
        Assert-Result 'git_init_main' ($gitApplied.exit_code -eq 0 -and $gitApplied.json.status -eq 'INITIALIZED' -and $gitApplied.json.branch -eq 'main') $gitApplied.raw

        & git -c core.excludesFile= -C $fresh config user.name 'Ask Harness Test'
        & git -c core.excludesFile= -C $fresh config user.email 'ask-harness@example.invalid'
        & git -c core.excludesFile= -c core.autocrlf=false -C $fresh add --all
        & git -c core.excludesFile= -C $fresh commit -m 'test: bootstrap baseline' | Out-Null

        $inputPath = Join-Path $fresh '.harness\execution-input.json'
        $inputArgs = @(
            '-TargetRoot',$fresh,
            '-FeatureId','feature',
            '-DomainContextPath','CONTEXT.md',
            '-SpecPath','.scratch/feature/spec.md',
            '-AdrPaths','docs/architecture/ADR-001.md',
            '-WorktreePath',(Join-Path $testRoot 'worktrees\feature'),
            '-Branch','codex/feature',
            '-OutputPath',$inputPath,
            '-SpecApprovedByHuman',
            '-TechnicalDesignApprovedByHuman'
        )
        $draft = Invoke-ScriptJson $inputScript $inputArgs
        Assert-Result 'draft_input_created' ($draft.exit_code -eq 0 -and (Test-Path -LiteralPath $inputPath)) $draft.raw
        $draftJson = Get-Content -LiteralPath $inputPath -Raw | ConvertFrom-Json
        Assert-Result 'draft_not_execution_authorized' ($draftJson.authorization.execution_authorized -eq $false) ($draftJson.authorization | ConvertTo-Json -Compress)

        $beforeStart = Invoke-ScriptJson $bootstrapScript @('-TargetRoot',$fresh,'-ExecutionInputPath',$inputPath)
        Assert-Result 'bootstrap_waits_for_start' ($beforeStart.exit_code -eq 0 -and $beforeStart.json.status -eq 'READY_FOR_START_CONFIRMATION') $beforeStart.raw

        $authorized = Invoke-ScriptJson $inputScript ($inputArgs + @('-ExecutionAuthorized'))
        Assert-Result 'authorized_input_updated' ($authorized.exit_code -eq 0) $authorized.raw
        $ready = Invoke-ScriptJson $bootstrapScript @('-TargetRoot',$fresh,'-ExecutionInputPath',$inputPath)
        Assert-Result 'bootstrap_ready_for_orchestrator' ($ready.exit_code -eq 0 -and $ready.json.status -eq 'READY_FOR_AUTONOMOUS_EXECUTION') $ready.raw

        $providedPath = Join-Path $fresh '.harness\provided-input.json'
        $providedArgs = @(
            '-TargetRoot',$fresh,'-FeatureId','feature-ui','-DomainContextPath','CONTEXT.md','-SpecPath','.scratch/feature/spec.md',
            '-AdrPaths','docs/architecture/ADR-001.md','-InputProfile','matt_plus_uiux','-UiMode','provided',
            '-HandoffPath','docs/ui-ux/feature/handoff.md','-UiContractPath','docs/ui-ux/feature/UI-CONTRACT.md',
            '-DesignTokensPath','docs/ui-ux/feature/tokens.json','-DesignTokensCssPath','docs/ui-ux/feature/tokens.css',
            '-ComponentSpecsPath','docs/ui-ux/feature/components.md','-StateMatrixPath','docs/ui-ux/feature/states.md',
            '-WorktreePath',(Join-Path $testRoot 'worktrees\feature-ui'),'-Branch','codex/feature-ui','-OutputPath',$providedPath,
            '-SpecApprovedByHuman','-TechnicalDesignApprovedByHuman'
        )
        $provided = Invoke-ScriptJson $inputScript $providedArgs
        $providedJson = Get-Content -LiteralPath $providedPath -Raw | ConvertFrom-Json
        Assert-Result 'provided_ui_input_created' ($provided.exit_code -eq 0 -and $providedJson.input_profile -eq 'matt_plus_uiux') $provided.raw
        Assert-Result 'provided_ui_contract_recorded' ($providedJson.authorities.ui_baseline.ui_contract -eq 'docs/ui-ux/feature/UI-CONTRACT.md') ($providedJson.authorities.ui_baseline | ConvertTo-Json -Compress)
    }
} finally {
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    $resolvedTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTestRoot.StartsWith($resolvedTempRoot,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTestRoot)) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}

$valid = $failures.Count -eq 0
[pscustomobject]@{ schema_version='1.0.0'; valid=$valid; check_count=$checks.Count; errors=$failures; checks=$checks } | ConvertTo-Json -Depth 8
if (-not $valid) { exit 1 }
