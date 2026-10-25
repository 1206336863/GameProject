$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$engineFolder = Join-Path $repoRoot 'tools/godot'
New-Item -ItemType Directory -Force -Path $engineFolder | Out-Null
$archiveFile = Join-Path $engineFolder 'godot-4.7.2.zip'
$engineFile = Join-Path $engineFolder 'Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $engineFile)) {
    Invoke-WebRequest 'https://downloads.godotengine.org/?flavor=stable&platform=windows.64&slug=win64.exe.zip&version=4.7.2' -OutFile $archiveFile
    Expand-Archive -LiteralPath $archiveFile -DestinationPath $engineFolder -Force
}
& $engineFile --version
