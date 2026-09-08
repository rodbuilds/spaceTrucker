# Sync the Space Trucker mod into Avorion's mods directory, overwriting.
# Run from anywhere; paths are absolute.

$ErrorActionPreference = 'Stop'

$source = Split-Path -Parent $PSScriptRoot   # the repo root
$dest   = "$env:APPDATA\Avorion\mods\spaceTrucker"

if (-not (Test-Path $dest)) {
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
}

Write-Host "Deploying from: $source"
Write-Host "Deploying to:   $dest"
Write-Host ""

# Top-level files: copy individually so we don't accidentally pull anything else.
foreach ($file in @('modinfo.lua', 'README.md', 'thumbnail.png')) {
    $src = Join-Path $source $file
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $dest -Force
        Write-Host "  copied  $file"
    }
}

# data/ tree: mirror so deletions in repo propagate to deployed mod.
# Robocopy exit codes 0-7 are success; 8+ are real failures.
$dataSrc = Join-Path $source 'data'
$dataDst = Join-Path $dest   'data'
if (Test-Path $dataSrc) {
    Write-Host ""
    Write-Host "  mirroring data/..."
    robocopy $dataSrc $dataDst /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) {
        Write-Error "robocopy failed with exit code $LASTEXITCODE"
        exit 1
    }
    Write-Host "  data/ synced."
}

Write-Host ""
Write-Host "Deploy complete." -ForegroundColor Green
