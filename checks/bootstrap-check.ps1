[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$TargetRoot,
    [Parameter(Mandatory = $true)] [string]$ExecutionInputPath
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($TargetRoot)
$inputPath = if ([IO.Path]::IsPathRooted($ExecutionInputPath)) { [IO.Path]::GetFullPath($ExecutionInputPath) } else { [IO.Path]::GetFullPath((Join-Path $root $ExecutionInputPath)) }
$checks = [System.Collections.Generic.List[object]]::new()
$blockers = [System.Collections.Generic.List[string]]::new()

function Add-Check {
    param([string]$Name,[bool]$Passed,[string]$Detail,[string]$Blocker)
    $checks.Add([pscustomobject]@{name=$Name;passed=$Passed;detail=$Detail})
    if (-not $Passed -and $Blocker) { $blockers.Add($Blocker) }
}
function Invoke-GitCapture {
    param([string[]]$Arguments)
    $old=$ErrorActionPreference; $ErrorActionPreference='Continue'
    try {
        $output=& git @Arguments 2>&1; $code=$LASTEXITCODE
        $clean=@($output | ForEach-Object { if($_ -is [Management.Automation.ErrorRecord]){$_.Exception.Message}else{[string]$_} }) -join [Environment]::NewLine
        [pscustomobject]@{exit_code=$code;output=$clean.Trim()}
    } finally { $ErrorActionPreference=$old }
}
function Resolve-InRoot {
    param([string]$Candidate)
    $combined=if([IO.Path]::IsPathRooted($Candidate)){$Candidate}else{Join-Path $root $Candidate}
    $full=[IO.Path]::GetFullPath($combined)
    $prefix=$root.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    if(-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw "路径位于目标根目录之外：$Candidate"}
    $full
}
function Normalize-GitRemote {
    param([string]$Remote)
    $value=([string]$Remote).Trim()
    if($value -match '^git@github\.com:(.+)$'){$value="https://github.com/$($Matches[1])"}
    elseif($value -match '^ssh://git@github\.com/(.+)$'){$value="https://github.com/$($Matches[1])"}
    ($value.TrimEnd('/') -replace '\.git$','').ToLowerInvariant()
}

Add-Check 'target_root_exists' (Test-Path -LiteralPath $root -PathType Container) $root '目标项目不存在。'
Add-Check 'execution_input_exists' (Test-Path -LiteralPath $inputPath -PathType Leaf) $inputPath '执行输入缺失。'
if ($blockers.Count -gt 0) {
    [pscustomobject]@{schema_version='1.0.0';status='BLOCKED_INPUT';project_root=$root;checks=$checks;blockers=$blockers;next_action='补齐缺失的 Bootstrap 输入。'}|ConvertTo-Json -Depth 8
    exit 2
}

$input = Get-Content -LiteralPath $inputPath -Raw | ConvertFrom-Json
Add-Check 'target_root_matches_input' ([IO.Path]::GetFullPath([string]$input.target_root) -eq $root) ([string]$input.target_root) '执行输入指向了其他项目。'
foreach ($required in @('AGENTS.md','HARNESS.md','HARNESS_VERSION','harness-source.yaml','.agents\skills\ask-harness\SKILL.md','harness.config.yaml','workflow.yaml','roles\orchestrator.md','checks\intake-check.ps1')) {
    Add-Check "harness_$required" (Test-Path -LiteralPath (Join-Path $root $required) -PathType Leaf) $required "Harness 文件缺失：$required"
}

$gitPrefix=@('-c','core.excludesFile=','-C',$root)
$inside=Invoke-GitCapture ($gitPrefix+@('rev-parse','--is-inside-work-tree'))
$isGit=$inside.exit_code -eq 0 -and $inside.output -eq 'true'
Add-Check 'git_repository' $isGit $inside.output 'Git 仓库尚未初始化。'
if ($isGit) {
    $head=Invoke-GitCapture ($gitPrefix+@('rev-parse','HEAD'))
    Add-Check 'git_has_baseline_commit' ($head.exit_code -eq 0) $head.output 'Git 基线提交缺失。'
    $status=(Invoke-GitCapture ($gitPrefix+@('status','--porcelain'))).output
    Add-Check 'git_worktree_clean' ([string]::IsNullOrWhiteSpace($status)) $(if($status){$status}else{'干净'}) '项目包含未提交改动。'
    $origin=(Invoke-GitCapture ($gitPrefix+@('config','--get','remote.origin.url'))).output
    $templateSource=Get-Content -LiteralPath (Join-Path $root 'harness-source.yaml') -Raw | ConvertFrom-Json
    $normalizedOrigin=Normalize-GitRemote $origin
    $normalizedTemplate=Normalize-GitRemote ([string]$templateSource.template_repository)
    $usesTemplateRemote=-not [string]::IsNullOrWhiteSpace($normalizedOrigin) -and $normalizedOrigin -eq $normalizedTemplate
    Add-Check 'git_product_origin' (-not $usesTemplateRemote) $(if($origin){$origin}else{'未配置，仅本地'}) 'origin 仍指向 Harness 模板仓库；产品提交前请选择产品仓库。'
}

Add-Check 'spec_approved' ($input.authorization.spec_approved_by_human -eq $true) ([string]$input.authorization.spec_approved_by_human) 'Spec 批准缺失。'
Add-Check 'technical_design_approved' ($input.authorization.technical_design_approved_by_human -eq $true) ([string]$input.authorization.technical_design_approved_by_human) '技术设计批准缺失。'

foreach ($authorityName in @('domain_context','spec')) {
    try {
        $path=Resolve-InRoot ([string]$input.authorities.$authorityName)
        $valid=(Test-Path -LiteralPath $path -PathType Leaf) -and (Get-Item -LiteralPath $path).Length -gt 0
        Add-Check "authority_$authorityName" $valid $path "权威文件缺失：$authorityName"
    } catch { Add-Check "authority_$authorityName" $false $_.Exception.Message "权威文件无效：$authorityName" }
}
foreach ($adr in @($input.authorities.adr)) {
    try {
        $path=Resolve-InRoot ([string]$adr)
        $valid=(Test-Path -LiteralPath $path -PathType Leaf) -and (Get-Item -LiteralPath $path).Length -gt 0
        Add-Check 'authority_adr' $valid $path '技术决策权威文件缺失。'
    } catch { Add-Check 'authority_adr' $false $_.Exception.Message '技术决策权威文件无效。' }
}

$intakeReady=$false
if ($blockers.Count -eq 0) {
    $intakeScript=Join-Path $root 'checks\intake-check.ps1'
    $intakeArgs=@(
        '-TargetRoot',$root,
        '-DomainContextPath',[string]$input.authorities.domain_context,
        '-SpecPath',[string]$input.authorities.spec,
        '-InputProfile',[string]$input.input_profile,
        '-UiMode',[string]$input.ui_mode
    )
    if (@($input.authorities.adr).Count -gt 0) { $intakeArgs += @('-AdrPaths') + @($input.authorities.adr) }
    if ([string]$input.ui_mode -eq 'reuse_existing') {
        $intakeArgs += @('-ExistingUiSources') + @($input.authorities.existing_ui_sources)
    }
    if ([string]$input.ui_mode -eq 'provided') {
        $intakeArgs += @(
            '-HandoffPath',[string]$input.authorities.ui_baseline.handoff_manifest,
            '-UiContractPath',[string]$input.authorities.ui_baseline.ui_contract,
            '-DesignTokensPath',[string]$input.authorities.ui_baseline.design_tokens_json,
            '-DesignTokensCssPath',[string]$input.authorities.ui_baseline.design_tokens_css,
            '-ComponentSpecsPath',[string]$input.authorities.ui_baseline.component_specs,
            '-StateMatrixPath',[string]$input.authorities.ui_baseline.state_matrix
        )
    }
    $intakeOutput=& powershell -NoProfile -ExecutionPolicy Bypass -File $intakeScript @intakeArgs
    $intakeCode=$LASTEXITCODE
    try { $intakeResult=($intakeOutput -join [Environment]::NewLine)|ConvertFrom-Json; $intakeReady=$intakeCode -eq 0 -and $intakeResult.ready -eq $true }
    catch { $intakeReady=$false }
    Add-Check 'intake_ready' $intakeReady $(if($intakeOutput){$intakeOutput -join [Environment]::NewLine}else{'无输出'}) 'Intake 检查失败。'
}

$gitFailed = @($checks | Where-Object { $_.name -like 'git_*' -and -not $_.passed }).Count -gt 0
$status = if ($gitFailed) { 'BLOCKED_GIT' } elseif ($blockers.Count -gt 0) { 'BLOCKED_INPUT' } elseif ($input.authorization.execution_authorized -eq $true) { 'READY_FOR_AUTONOMOUS_EXECUTION' } else { 'READY_FOR_START_CONFIRMATION' }
$next = if ($status -eq 'READY_FOR_START_CONFIRMATION') { '只询问一个最终问题：是否授权自主执行？' } elseif ($status -eq 'READY_FOR_AUTONOMOUS_EXECUTION') { '在同一根对话中加载 roles/orchestrator.md 并继续执行。' } else { '每次解决一个阻断项，然后重新运行 bootstrap-check。' }

[pscustomobject]@{
    schema_version='1.0.0';status=$status;project_root=$root;execution_input=$inputPath
    execution_authorized=($input.authorization.execution_authorized -eq $true);intake_ready=$intakeReady
    checks=$checks;blockers=$blockers;next_action=$next
}|ConvertTo-Json -Depth 10
if($blockers.Count -gt 0){exit 2}
