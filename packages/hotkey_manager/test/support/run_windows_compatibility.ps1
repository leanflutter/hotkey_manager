# Run tests in the logged-on desktop, without mouse or keyboard input.
param([switch]$DesktopSession, [string]$RunDirectory)
$ErrorActionPreference = 'Stop'
$package = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if ($DesktopSession) {
  $result = @{ session = (Get-Process -Id $PID).SessionId; exitCode = 1 }
  try {
    $python = (Get-Command python.exe).Source
    $script = Join-Path $PSScriptRoot 'verify_windows.py'
    $process = Start-Process $python -ArgumentList ('"' + $script + '"') -WorkingDirectory $package -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $RunDirectory 'stdout.log') -RedirectStandardError (Join-Path $RunDirectory 'stderr.log')
    $process.Handle | Out-Null
    if (-not $process.WaitForExit(600000)) {
      Stop-Process -Id $process.Id -Force
      throw 'Compatibility tests timed out'
    }
    $result.exitCode = $process.ExitCode
  } catch {
    $_ | Out-String | Out-File (Join-Path $RunDirectory 'launcher-error.log') -Encoding utf8
  } finally {
    $result | ConvertTo-Json | Out-File (Join-Path $RunDirectory 'result.json') -Encoding utf8
  }
  exit $result.exitCode
}
if (-not (Get-Process explorer -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -ne 0 })) {
  throw 'No logged-on desktop session'
}
$runId = [Guid]::NewGuid().ToString('N')
$RunDirectory = Join-Path $package ('build\compatibility_audit\windows-' + $runId)
New-Item -ItemType Directory -Path $RunDirectory -Force | Out-Null
$taskName = 'HotkeyManager-Compatibility-' + $runId
$arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -DesktopSession -RunDirectory "' + $RunDirectory + '"'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
$principal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value) -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::FromMinutes(11)) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
try {
  Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $settings | Out-Null
  Start-ScheduledTask -TaskName $taskName
  $deadline = (Get-Date).AddSeconds(620)
  $resultFile = Join-Path $RunDirectory 'result.json'
  while (-not (Test-Path $resultFile) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 250 }
  if (-not (Test-Path $resultFile)) { throw "Desktop tests timed out: $RunDirectory" }
  foreach ($name in @('stdout.log', 'stderr.log', 'launcher-error.log')) {
    $log = Join-Path $RunDirectory $name
    if (Test-Path $log) { Get-Content $log }
  }
  $result = Get-Content $resultFile -Raw | ConvertFrom-Json
  $result | ConvertTo-Json
  if ($result.session -eq 0 -or $result.exitCode -ne 0) { throw "Desktop tests failed: $RunDirectory" }
} finally {
  Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
}
