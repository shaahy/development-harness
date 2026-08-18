[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$TargetRoot,
    [Parameter(Mandatory = $true)] [string]$DomainContextPath,
    [Parameter(Mandatory = $true)] [string]$SpecPath,
    [Parameter(Mandatory = $true)] [ValidateSet('matt_spec_only','matt_plus_uiux')] [string]$InputProfile,
    [Parameter(Mandatory = $true)] [ValidateSet('auto_detect','none','reuse_existing','provided','auto_generate')] [string]$UiMode,
    [string[]]$AdrPaths = @(),
    [string[]]$ExistingUiSources = @(),
    [string]$HandoffPath,
    [string]$UiContractPath,
    [string]$DesignTokensPath,
    [string]$DesignTokensCssPath,
    [string]$ComponentSpecsPath,
    [string]$StateMatrixPath
)

$ErrorActionPreference = 'Stop'
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Passed, [string]$Detail)
    $checks.Add([pscustomobject]@{ name = $Name; passed = $Passed; detail = $Detail })
}

function Resolve-InRoot {
    param([string]$Root, [string]$Candidate)
    if ([string]::IsNullOrWhiteSpace($Candidate)) { throw 'Path is empty.' }
    $combined = if ([IO.Path]::IsPathRooted($Candidate)) { $Candidate } else { Join-Path $Root $Candidate }
    $full = [IO.Path]::GetFullPath($combined)
    $rootPrefix = $Root.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Authority path is outside target root: $Candidate" }
    return $full
}

function Test-Authority {
    param([string]$Name, [string]$Root, [string]$Candidate)
    try {
        $full = Resolve-InRoot -Root $Root -Candidate $Candidate
        $valid = (Test-Path -LiteralPath $full -PathType Leaf) -and (Get-Item -LiteralPath $full).Length -gt 0
        Add-Check "authority_$Name" $valid $full
    } catch { Add-Check "authority_$Name" $false $_.Exception.Message }
}

$root = [IO.Path]::GetFullPath($TargetRoot)
Add-Check 'target_root_exists' (Test-Path -LiteralPath $root -PathType Container) $root
Test-Authority 'domain_context' $root $DomainContextPath
Test-Authority 'spec' $root $SpecPath
foreach ($adr in $AdrPaths) { Test-Authority 'adr' $root $adr }

$profileModeValid = ($InputProfile -eq 'matt_plus_uiux' -and $UiMode -eq 'provided') -or
    ($InputProfile -eq 'matt_spec_only' -and $UiMode -in @('auto_detect','none','reuse_existing','auto_generate'))
Add-Check 'profile_ui_mode_compatible' $profileModeValid "$InputProfile / $UiMode"

if ($UiMode -eq 'reuse_existing') {
    Add-Check 'existing_ui_sources_supplied' ($ExistingUiSources.Count -gt 0) ([string]$ExistingUiSources.Count)
    foreach ($source in $ExistingUiSources) { Test-Authority 'existing_ui_source' $root $source }
}

if ($UiMode -eq 'provided') {
    $ui = [ordered]@{ handoff_manifest=$HandoffPath; ui_contract=$UiContractPath; design_tokens_json=$DesignTokensPath; design_tokens_css=$DesignTokensCssPath; component_specs=$ComponentSpecsPath; state_matrix=$StateMatrixPath }
    foreach ($entry in $ui.GetEnumerator()) { Test-Authority $entry.Key $root $entry.Value }
    try {
        $tokens = Resolve-InRoot -Root $root -Candidate $DesignTokensPath
        if (Test-Path -LiteralPath $tokens -PathType Leaf) { $null = Get-Content -LiteralPath $tokens -Raw | ConvertFrom-Json; Add-Check 'design_tokens_json_parse' $true $tokens }
    } catch { Add-Check 'design_tokens_json_parse' $false $_.Exception.Message }
}

$ready = -not ($checks | Where-Object { -not $_.passed })
[pscustomobject]@{ schema_version='1.1.0'; ready=$ready; target_root=$root; input_profile=$InputProfile; ui_mode=$UiMode; checks=$checks } | ConvertTo-Json -Depth 8
if (-not $ready) { exit 2 }
