param([string]$EnginePath = '', [string]$PackPath = '', [string]$LogPath = '')
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
if (-not $EnginePath) {
    $repoRoot = Split-Path $projectPath -Parent
    $EnginePath = Join-Path $repoRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
}
$engineArgs = @('--headless', '--quit-after', '1200')
if ($PackPath) { $engineArgs += @('--main-pack', $PackPath) }
else { $engineArgs += @('--path', $projectPath) }
$engineArgs += @('--', '--test')
$lines = & $EnginePath @engineArgs 2>&1
$engineExit = $LASTEXITCODE
$output = $lines | Out-String
Write-Output $output
if ($LogPath) { [IO.File]::WriteAllText($LogPath, $output, [Text.UTF8Encoding]::new($false)) }
if ($engineExit -ne 0 -or $output -match 'SCRIPT ERROR|ERROR:|Assertion failed' -or
    $output -notmatch 'NEON25D_COMFORT_TESTS_OK' -or $output -notmatch 'NEON25D_LEVEL_TESTS_OK' -or $output -notmatch 'NEON25D_COMBAT_TESTS_OK' -or $output -notmatch 'NEON25D_DEEP_TESTS_OK' -or $output -notmatch 'NEON25D_TESTS_OK') {
    throw 'Native tests failed or did not complete. Inspect the log above.'
}
