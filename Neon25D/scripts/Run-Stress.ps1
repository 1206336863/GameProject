param(
 [int]$Seconds=600,
 [string]$Tag='stress',
 [string]$EnginePath='',
 [string]$OutputDirectory=''
)
$ErrorActionPreference='Stop'
if ($Seconds -lt 15 -or $Seconds -gt 7200) { throw 'Seconds must be between 15 and 7200.' }
if ($Tag -notmatch '^[A-Za-z0-9_-]+$') { throw 'Use letters, digits, underscores or hyphens in Tag.' }
$projectPath=Split-Path $PSScriptRoot -Parent
if (-not $EnginePath) { $EnginePath=Join-Path (Split-Path $projectPath -Parent) 'tools/godot/Godot_v4.7.2-stable_win64_console.exe' }
if (-not $OutputDirectory) { $OutputDirectory=Join-Path $projectPath 'build/benchmarks' }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory)
$out=Join-Path $OutputDirectory "$Tag.json"
$stdout=Join-Path $OutputDirectory "$Tag.log"
$stderr=Join-Path $OutputDirectory "$Tag-errors.log"
$arguments=@('--path', ('"'+$projectPath+'"'), '--', "--perf-seconds=$Seconds", ('"--perf-output='+$out+'"'))
$process=Start-Process -FilePath $EnginePath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$samples=@(); $watch=[Diagnostics.Stopwatch]::StartNew();$nextReport=0;$gameProcess=$null
while (-not $process.HasExited) {
 $process.Refresh()
 $log=Get-Content $stdout -Raw -ErrorAction SilentlyContinue
 if ($log -match 'PERF_PID (\d+)') { $gameProcess=Get-Process -Id ([int]$Matches[1]) -ErrorAction SilentlyContinue }
 if ($gameProcess) {
  $gameProcess.Refresh()
  $samples += [PSCustomObject]@{seconds=[math]::Round($watch.Elapsed.TotalSeconds,2);private_mb=[math]::Round($gameProcess.PrivateMemorySize64/1MB,2);working_mb=[math]::Round($gameProcess.WorkingSet64/1MB,2)}
  if ($watch.Elapsed.TotalSeconds -ge $nextReport) { Write-Output "$Tag elapsed=$([int]$watch.Elapsed.TotalSeconds)s private=$([int]($gameProcess.PrivateMemorySize64/1MB))MB"; $nextReport+=30 }
 }
 Start-Sleep -Seconds 2
 if ($watch.Elapsed.TotalSeconds -gt $Seconds+240) {
  if ($gameProcess -and -not $gameProcess.HasExited) { $gameProcess.Kill() }
  if (-not $process.HasExited) { $process.Kill() }
  throw 'Benchmark timed out'
 }
}
$samples | ConvertTo-Json | Set-Content (Join-Path $OutputDirectory "$Tag-process.json") -Encoding utf8
$log=Get-Content $stdout -Raw
Write-Output $log
$errors=Get-Content $stderr -Raw
if ($errors) { Write-Output $errors }
if ($process.ExitCode -ne 0 -or $errors -match 'SCRIPT ERROR|ERROR:' -or $log -notmatch 'PERF_BENCH_OK' -or -not (Test-Path $out)) { throw 'Benchmark failed' }
