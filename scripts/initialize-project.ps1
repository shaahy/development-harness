[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$TargetRoot,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$target = [IO.Path]::GetFullPath($TargetRoot)
if (-not (Test-Path -LiteralPath $target -PathType Container)) { throw "Target project not found: $target" }

function Invoke-GitCapture {
    param([string[]]$Arguments)
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $output = & git @Arguments 2>&1; $code = $LASTEXITCODE
        $clean = @($output | ForEach-Object { if ($_ -is [Management.Automation.ErrorRecord]) { $_.Exception.Message } else { [string]$_ } }) -join [Environment]::NewLine
        [pscustomobject]@{exit_code=$code;output=$clean.Trim()}
    } finally { $ErrorActionPreference = $old }
}

$gitPrefix = @('-c','core.excludesFile=','-C',$target)
$inside = Invoke-GitCapture ($gitPrefix + @('rev-parse','--is-inside-work-tree'))
if ($inside.exit_code -eq 0 -and $inside.output -eq 'true') {
    $branch = (Invoke-GitCapture ($gitPrefix + @('branch','--show-current'))).output
    $headResult = Invoke-GitCapture ($gitPrefix + @('rev-parse','HEAD'))
    $status = (Invoke-GitCapture ($gitPrefix + @('status','--porcelain'))).output
    [pscustomobject]@{
        schema_version='1.0.0'; status='EXISTING_REPOSITORY'; applied=$false; target_root=$target
        branch=$branch; head=$(if($headResult.exit_code -eq 0){$headResult.output}else{$null})
        dirty=(-not [string]::IsNullOrWhiteSpace($status)); next_action='Preserve existing history; inspect changes before baseline decisions.'
    } | ConvertTo-Json -Depth 5
    exit 0
}

if (-not $Apply) {
    [pscustomobject]@{
        schema_version='1.0.0'; status='READY_TO_INITIALIZE'; applied=$false; target_root=$target
        branch='main'; next_action='Obtain user authorization, then rerun with -Apply.'
    } | ConvertTo-Json -Depth 5
    exit 0
}

$initialized = Invoke-GitCapture ($gitPrefix + @('init','-b','main'))
if ($initialized.exit_code -ne 0) { throw "git init failed: $($initialized.output)" }
$branch = (Invoke-GitCapture ($gitPrefix + @('branch','--show-current'))).output

[pscustomobject]@{
    schema_version='1.0.0'; status='INITIALIZED'; applied=$true; target_root=$target
    branch=$branch; head=$null; dirty=$true; next_action='Review files and create an explicit baseline commit.'
} | ConvertTo-Json -Depth 5
