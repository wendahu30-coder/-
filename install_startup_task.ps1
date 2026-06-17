param(
    [string]$TaskName = "CampusAutoLogin",
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LoginExe = Join-Path $ScriptDir "login.exe"
$LoginScript = Join-Path $ScriptDir "login.py"
$RunnerScript = Join-Path $ScriptDir "connect_and_login.ps1"
$Config = Join-Path $ScriptDir "config.json"

if (-not (Test-Path -LiteralPath $LoginExe) -and -not (Test-Path -LiteralPath $LoginScript)) {
    throw "login.exe or login.py not found."
}
if (-not (Test-Path -LiteralPath $RunnerScript)) {
    throw "connect_and_login.ps1 not found: $RunnerScript"
}

if (-not (Test-Path -LiteralPath $Config)) {
    throw "config.json not found. Run setup.ps1 first."
}

function Install-StartupShortcut {
    $StartupDir = [Environment]::GetFolderPath("Startup")
    if (-not $StartupDir) {
        throw "Startup folder not found."
    }

    $ShortcutPath = Join-Path $StartupDir "$TaskName.lnk"
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$RunnerScript`" -Python `"$Python`""
    $Shortcut.WorkingDirectory = $ScriptDir
    $Shortcut.WindowStyle = 7
    $Shortcut.Description = "Campus auto login"
    $Shortcut.Save()

    Write-Host "Startup shortcut installed: $ShortcutPath"
    Write-Host "This fallback does not require administrator permission."
}

try {
    $Action = New-ScheduledTaskAction `
        -Execute "powershell" `
        -Argument "-ExecutionPolicy Bypass -File `"$RunnerScript`" -Python `"$Python`""

    $Trigger = New-ScheduledTaskTrigger -AtLogOn

    $Principal = New-ScheduledTaskPrincipal `
        -UserId $env:USERNAME `
        -LogonType Interactive `
        -RunLevel Limited

    $Settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -MultipleInstances IgnoreNew

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Principal $Principal `
        -Settings $Settings `
        -Force | Out-Null

    Write-Host "Scheduled task installed: $TaskName"
}
catch {
    Write-Host "Scheduled task installation failed. Falling back to Startup folder shortcut." -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Install-StartupShortcut
}

Write-Host "You can test with:"
Write-Host "powershell -ExecutionPolicy Bypass -File `"$RunnerScript`""
