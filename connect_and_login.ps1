param(
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Config = Join-Path $ScriptDir "config.json"
$LoginExe = Join-Path $ScriptDir "login.exe"
$LoginScript = Join-Path $ScriptDir "login.py"

if (-not (Test-Path -LiteralPath $Config)) {
    throw "config.json not found. Run setup.ps1 first."
}
if (-not (Test-Path -LiteralPath $LoginExe) -and -not (Test-Path -LiteralPath $LoginScript)) {
    throw "login.exe or login.py not found."
}

$cfg = Get-Content -LiteralPath $Config -Raw -Encoding UTF8 | ConvertFrom-Json
$ssid = $cfg.wifi_ssid

if ($ssid) {
    Write-Host "Connecting Wi-Fi: $ssid"
    & netsh wlan connect name="$ssid" ssid="$ssid" | Out-Null
    Start-Sleep -Seconds 8
}

if (Test-Path -LiteralPath $LoginExe) {
    & $LoginExe --config $Config --verbose
}
else {
    & $Python $LoginScript --config $Config --verbose
}
