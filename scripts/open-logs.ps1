# Open the most recent client and server logs for the spacetrucker1 galaxy.

$ErrorActionPreference = 'Stop'

$clientDir = "$env:APPDATA\Avorion"
$serverDir = "$env:APPDATA\Avorion\galaxies\spacetrucker2"

function Open-Latest($dir, $pattern, $label) {
    if (-not (Test-Path $dir)) {
        Write-Warning "$label directory not found: $dir"
        return
    }
    $log = Get-ChildItem -Path $dir -Filter $pattern -File |
           Sort-Object LastWriteTime -Descending |
           Select-Object -First 1
    if (-not $log) {
        Write-Warning "No $label log found in $dir matching '$pattern'"
        return
    }
    Write-Host "Opening $label log: $($log.Name)"
    Invoke-Item $log.FullName
}

Open-Latest $clientDir 'clientlog *.txt' 'client'
Open-Latest $serverDir 'serverlog *.txt' 'server'
