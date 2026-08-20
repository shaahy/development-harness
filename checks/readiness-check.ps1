[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$TargetRoot,
    [Parameter(Mandatory = $true)] [string]$SpecPath,
    [Parameter(Mandatory = $true)] [string]$PlanPath,
    [Parameter(Mandatory = $true)] [string]$PlanEvidencePath,
    [Parameter(Mandatory = $true)] [ValidateSet('none','reuse_existing','provided','auto_generate')] [string]$UiMode,
    [string[]]$UiAuthorityPaths = @(),
    [switch]$AllowDirtyWorktree
)

$ErrorActionPreference = 'Stop'
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check { param([string]$Name,[bool]$Passed,[string]$Detail); $checks.Add([pscustomobject]@{name=$Name;passed=$Passed;detail=$Detail}) }
function Invoke-GitCapture {
    param([string[]]$Arguments)
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $output = & git @Arguments 2>&1; $code = $LASTEXITCODE
        $clean = @($output | ForEach-Object { if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { [string]$_ } }) -join [Environment]::NewLine
        [pscustomobject]@{exit_code=$code;output=$clean.Trim()}
    } finally { $ErrorActionPreference = $old }
}
function Resolve-InRoot {
    param([string]$Root,[string]$Candidate)
    if ([string]::IsNullOrWhiteSpace($Candidate)) { throw '路径为空。' }
    $combined = if ([IO.Path]::IsPathRooted($Candidate)) { $Candidate } else { Join-Path $Root $Candidate }
    $full = [IO.Path]::GetFullPath($combined)
    $prefix = $Root.TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw "权威路径位于目标根目录之外：$Candidate" }
    $full
}
function Test-Authority {
    param([string]$Name,[string]$Root,[string]$Candidate)
    try { $full=Resolve-InRoot $Root $Candidate; $ok=(Test-Path -LiteralPath $full -PathType Leaf) -and (Get-Item -LiteralPath $full).Length -gt 0; Add-Check $Name $ok $full }
    catch { Add-Check $Name $false $_.Exception.Message }
}

$root=[IO.Path]::GetFullPath($TargetRoot)
Add-Check 'target_root_exists' (Test-Path -LiteralPath $root -PathType Container) $root
$gitInside=$false; $branch=$null; $baseCommit=$null; $dirty=$null
if (Test-Path -LiteralPath $root -PathType Container) {
    $gitPrefix=@('-c','core.excludesFile=','-C',$root)
    $inside=Invoke-GitCapture ($gitPrefix+@('rev-parse','--is-inside-work-tree'))
    $gitInside=$inside.exit_code -eq 0 -and $inside.output -eq 'true'; Add-Check 'git_repository' $gitInside $inside.output
    if ($gitInside) {
        $branch=(Invoke-GitCapture ($gitPrefix+@('branch','--show-current'))).output
        $baseCommit=(Invoke-GitCapture ($gitPrefix+@('rev-parse','HEAD'))).output
        $status=(Invoke-GitCapture ($gitPrefix+@('status','--porcelain'))).output; $dirty=-not [string]::IsNullOrWhiteSpace($status)
        Add-Check 'worktree_clean_or_explicitly_allowed' (-not $dirty -or $AllowDirtyWorktree.IsPresent) $(if($dirty){'有未提交改动'}else{'干净'})
    }
}

Test-Authority 'authority_spec' $root $SpecPath
Test-Authority 'generated_implementation_plan' $root $PlanPath
Test-Authority 'plan_review_evidence' $root $PlanEvidencePath
if ($UiMode -ne 'none') {
    Add-Check 'ui_authorities_supplied' ($UiAuthorityPaths.Count -gt 0) ([string]$UiAuthorityPaths.Count)
    foreach ($path in $UiAuthorityPaths) { Test-Authority 'ui_authority' $root $path }
}

$ready=-not ($checks | Where-Object {-not $_.passed})
[pscustomobject]@{schema_version='1.1.0';ready=$ready;target_root=$root;ui_mode=$UiMode;branch=$branch;base_commit=$baseCommit;dirty=$dirty;checks=$checks} | ConvertTo-Json -Depth 8
if(-not $ready){exit 2}
