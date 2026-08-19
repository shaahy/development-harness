[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$TargetRoot,
    [string]$SourceRoot,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
    $SourceRoot = Split-Path -Parent $scriptDirectory
}
$source = [IO.Path]::GetFullPath($SourceRoot)
$target = [IO.Path]::GetFullPath($TargetRoot)

if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw "Harness source not found: $source" }
if (-not (Test-Path -LiteralPath $target -PathType Container)) { throw "Target project not found: $target" }

$fileMap = [ordered]@{
    'AGENTS.md' = 'AGENTS.md'
    'harness.config.yaml' = 'harness.config.yaml'
    'workflow.yaml' = 'workflow.yaml'
    'README.md' = 'HARNESS.md'
}
$directories = @('roles','contracts','templates','checks','scripts','examples')
$collisions = [System.Collections.Generic.List[object]]::new()
$skipped = [System.Collections.Generic.List[string]]::new()
$plannedFiles = [System.Collections.Generic.List[string]]::new()
$plannedDirectories = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Test-SameFile {
    param([string]$Left,[string]$Right)
    if (-not (Test-Path -LiteralPath $Right -PathType Leaf)) { return $false }
    return (Get-FileHash -LiteralPath $Left -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $Right -Algorithm SHA256).Hash
}

function Test-CompatibleDirectory {
    param([string]$SourceDirectory,[string]$TargetDirectory)
    if (-not (Test-Path -LiteralPath $TargetDirectory -PathType Container)) { return $false }
    foreach ($sourceFile in Get-ChildItem -LiteralPath $SourceDirectory -File -Recurse) {
        $relative = $sourceFile.FullName.Substring($SourceDirectory.Length).TrimStart('\','/')
        $targetFile = Join-Path $TargetDirectory $relative
        if (-not (Test-SameFile $sourceFile.FullName $targetFile)) { return $false }
    }
    return $true
}

foreach ($entry in $fileMap.GetEnumerator()) {
    $sourcePath = Join-Path $source $entry.Key
    $targetPath = Join-Path $target $entry.Value
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Harness source file missing: $sourcePath" }
    if (Test-Path -LiteralPath $targetPath) {
        if (Test-SameFile $sourcePath $targetPath) { $skipped.Add($entry.Value) }
        else { $collisions.Add([pscustomobject]@{path=$entry.Value;reason='existing file differs'}) }
    } else { $plannedFiles.Add($entry.Value) }
}

foreach ($directory in $directories) {
    $sourcePath = Join-Path $source $directory
    $targetPath = Join-Path $target $directory
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Container)) { throw "Harness source directory missing: $sourcePath" }
    if (Test-Path -LiteralPath $targetPath) {
        if (Test-CompatibleDirectory $sourcePath $targetPath) { $skipped.Add($directory) }
        else { $collisions.Add([pscustomobject]@{path=$directory;reason='existing directory contains missing or different Harness files'}) }
    } else { $plannedDirectories.Add($directory) }
}

foreach ($optional in @('.gitignore','.gitattributes')) {
    $sourcePath = Join-Path $source $optional
    $targetPath = Join-Path $target $optional
    if (-not (Test-Path -LiteralPath $targetPath)) { $plannedFiles.Add($optional) }
    elseif (Test-SameFile $sourcePath $targetPath) { $skipped.Add($optional) }
    else { $warnings.Add("$optional already exists and was preserved; merge Harness entries manually if needed.") }
}

if ($collisions.Count -gt 0) {
    [pscustomobject]@{
        schema_version='1.0.0'; status='BLOCKED_COLLISION'; applied=$false
        source_root=$source; target_root=$target; collisions=$collisions; warnings=$warnings
        next_action='Resolve or explicitly merge each collision; do not overwrite user files.'
    } | ConvertTo-Json -Depth 8
    exit 2
}

if (-not $Apply) {
    [pscustomobject]@{
        schema_version='1.0.0'; status='READY_TO_INSTALL'; applied=$false
        source_root=$source; target_root=$target; files=$plannedFiles; directories=$plannedDirectories
        skipped=$skipped; warnings=$warnings; next_action='Obtain user authorization, then rerun with -Apply.'
    } | ConvertTo-Json -Depth 8
    exit 0
}

foreach ($entry in $fileMap.GetEnumerator()) {
    $destination = Join-Path $target $entry.Value
    if (-not (Test-Path -LiteralPath $destination)) {
        Copy-Item -LiteralPath (Join-Path $source $entry.Key) -Destination $destination
    }
}
foreach ($directory in $directories) {
    $destination = Join-Path $target $directory
    if (-not (Test-Path -LiteralPath $destination)) {
        Copy-Item -LiteralPath (Join-Path $source $directory) -Destination $destination -Recurse
    }
}
foreach ($optional in @('.gitignore','.gitattributes')) {
    $destination = Join-Path $target $optional
    if (-not (Test-Path -LiteralPath $destination)) {
        Copy-Item -LiteralPath (Join-Path $source $optional) -Destination $destination
    }
}

[pscustomobject]@{
    schema_version='1.0.0'; status='INSTALLED'; applied=$true
    source_root=$source; target_root=$target; files=$plannedFiles; directories=$plannedDirectories
    skipped=$skipped; warnings=$warnings; next_action='Inspect Git state and continue bootstrap.'
} | ConvertTo-Json -Depth 8
