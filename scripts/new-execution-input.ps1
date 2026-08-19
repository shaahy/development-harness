[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$TargetRoot,
    [Parameter(Mandatory = $true)] [string]$FeatureId,
    [Parameter(Mandatory = $true)] [string]$DomainContextPath,
    [Parameter(Mandatory = $true)] [string]$SpecPath,
    [string[]]$AdrPaths = @(),
    [string[]]$ExistingUiSources = @(),
    [string]$HandoffPath,
    [string]$UiContractPath,
    [string]$DesignTokensPath,
    [string]$DesignTokensCssPath,
    [string]$ComponentSpecsPath,
    [string]$StateMatrixPath,
    [ValidateSet('matt_spec_only','matt_plus_uiux')] [string]$InputProfile = 'matt_spec_only',
    [ValidateSet('auto_detect','none','reuse_existing','provided','auto_generate')] [string]$UiMode = 'auto_detect',
    [string]$BaseRef = 'main',
    [Parameter(Mandatory = $true)] [string]$WorktreePath,
    [Parameter(Mandatory = $true)] [string]$Branch,
    [Parameter(Mandatory = $true)] [string]$OutputPath,
    [Parameter(Mandatory = $true)] [switch]$SpecApprovedByHuman,
    [Parameter(Mandatory = $true)] [switch]$TechnicalDesignApprovedByHuman,
    [switch]$ExecutionAuthorized
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($TargetRoot)
if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "Target project not found: $root" }

function Resolve-Authority {
    param([string]$Candidate)
    $combined = if ([IO.Path]::IsPathRooted($Candidate)) { $Candidate } else { Join-Path $root $Candidate }
    $full = [IO.Path]::GetFullPath($combined)
    $prefix = $root.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw "Authority is outside target root: $Candidate" }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf) -or (Get-Item -LiteralPath $full).Length -eq 0) { throw "Authority missing or empty: $Candidate" }
    return $full.Substring($prefix.Length).Replace('\','/')
}

$domain = Resolve-Authority $DomainContextPath
$spec = Resolve-Authority $SpecPath
$adrs = @($AdrPaths | ForEach-Object { Resolve-Authority $_ })
$authorityPayload = [ordered]@{domain_context=$domain;spec=$spec;adr=$adrs}

if ($InputProfile -eq 'matt_plus_uiux' -and $UiMode -ne 'provided') {
    throw 'matt_plus_uiux requires UiMode provided.'
}
if ($InputProfile -eq 'matt_spec_only' -and $UiMode -eq 'provided') {
    throw 'matt_spec_only cannot use UiMode provided; select matt_plus_uiux.'
}
if ($UiMode -eq 'reuse_existing') {
    if ($ExistingUiSources.Count -eq 0) { throw 'reuse_existing requires ExistingUiSources.' }
    $authorityPayload.existing_ui_sources = @($ExistingUiSources | ForEach-Object { Resolve-Authority $_ })
}
if ($UiMode -eq 'provided') {
    $uiCandidates = [ordered]@{
        handoff_manifest=$HandoffPath;ui_contract=$UiContractPath;design_tokens_json=$DesignTokensPath
        design_tokens_css=$DesignTokensCssPath;component_specs=$ComponentSpecsPath;state_matrix=$StateMatrixPath
    }
    $uiPayload = [ordered]@{}
    foreach ($entry in $uiCandidates.GetEnumerator()) {
        if ([string]::IsNullOrWhiteSpace([string]$entry.Value)) { throw "provided UI baseline requires $($entry.Key)." }
        $uiPayload[$entry.Key] = Resolve-Authority ([string]$entry.Value)
    }
    $authorityPayload.ui_baseline = $uiPayload
}
$output = if ([IO.Path]::IsPathRooted($OutputPath)) { [IO.Path]::GetFullPath($OutputPath) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputPath)) }
$outputPrefix = $root.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
if (-not $output.StartsWith($outputPrefix,[StringComparison]::OrdinalIgnoreCase)) { throw "Output path must be inside target root: $OutputPath" }
$outputDirectory = Split-Path -Parent $output
if (-not (Test-Path -LiteralPath $outputDirectory)) { $null = New-Item -ItemType Directory -Path $outputDirectory -Force }

$payload = [ordered]@{
    schema_version='1.1.0'
    feature_id=$FeatureId
    target_root=$root.Replace('\','/')
    input_profile=$InputProfile
    ui_mode=$UiMode
    authorization=[ordered]@{
        spec_approved_by_human=[bool]$SpecApprovedByHuman
        technical_design_approved_by_human=[bool]$TechnicalDesignApprovedByHuman
        execution_authorized=[bool]$ExecutionAuthorized
        auto_plan=$true
        auto_ui_baseline_when_needed=$true
        auto_commit_in_isolated_worktree=$true
    }
    authorities=$authorityPayload
    generated=[ordered]@{
        implementation_plan="docs/superpowers/plans/$FeatureId.md"
        plan_review_evidence='.harness/plan-evidence.md'
        generated_ui_root="docs/ui-ux/$FeatureId"
    }
    git=[ordered]@{
        base_ref=$BaseRef
        worktree_path=([IO.Path]::GetFullPath($WorktreePath)).Replace('\','/')
        branch=$Branch
    }
}

$json = $payload | ConvertTo-Json -Depth 10
[IO.File]::WriteAllText($output,$json + [Environment]::NewLine,[Text.UTF8Encoding]::new($false))

[pscustomobject]@{
    schema_version='1.0.0'; status=$(if($ExecutionAuthorized){'AUTHORIZED_INPUT_WRITTEN'}else{'DRAFT_INPUT_WRITTEN'})
    output_path=$output; execution_authorized=[bool]$ExecutionAuthorized; feature_id=$FeatureId
    next_action=$(if($ExecutionAuthorized){'Run bootstrap-check and hand off to Orchestrator.'}else{'Run Intake, then request final start confirmation.'})
} | ConvertTo-Json -Depth 5
