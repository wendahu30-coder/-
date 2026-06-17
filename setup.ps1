param(
    [string]$TaskName = "CampusAutoLogin",
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"

function T {
    param([string]$Base64Text)
    return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Base64Text))
}

function Read-RequiredText {
    param(
        [string]$Prompt,
        [string]$Example
    )

    while ($true) {
        $value = Read-Host $Prompt
        $value = $value.Trim()
        if ($value) {
            return $value
        }
        Write-Host "$(T '5LiN6IO95Li656m644CC56S65L6L77ya')$Example" -ForegroundColor Yellow
    }
}

function Convert-SecureStringToPlainText {
    param([securestring]$SecureText)

    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureText)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Template = Join-Path $ScriptDir "config.njuit.portal-login.json"
$Config = Join-Path $ScriptDir "config.json"
$LoginExe = Join-Path $ScriptDir "login.exe"
$LoginScript = Join-Path $ScriptDir "login.py"
$RunnerScript = Join-Path $ScriptDir "connect_and_login.ps1"
$Installer = Join-Path $ScriptDir "install_startup_task.ps1"

if (-not (Test-Path -LiteralPath $Template)) {
    throw "$(T '5om+5LiN5Yiw6YWN572u5qih5p2/77ya')$Template"
}
if (-not (Test-Path -LiteralPath $LoginExe) -and -not (Test-Path -LiteralPath $LoginScript)) {
    throw "login.exe or login.py not found."
}
if (-not (Test-Path -LiteralPath $RunnerScript)) {
    throw "$(T '5om+5LiN5YiwIFdpLUZpIOi/kOihjOiEmuacrO+8mg==')$RunnerScript"
}
if (-not (Test-Path -LiteralPath $Installer)) {
    throw "$(T '5om+5LiN5Yiw6Ieq5Yqo5Lu75Yqh5a6J6KOF6ISa5pys77ya')$Installer"
}

Write-Host ""
Write-Host (T '5qCh5Zut572R6Ieq5Yqo55m75b2V5Yid5aeL5YyW') -ForegroundColor Cyan
Write-Host (T '6LSm5Y+35ZCO57yA6K+35oyJ5L2g55qE6L+Q6JCl5ZWG6YCJ5oup5aGr5YaZ77ya') -ForegroundColor Cyan
Write-Host (T 'ICDmoKHlm63nlKjmiLfvvJrlrablj7fvvIzkuI3liqDlkI7nvIA=') -ForegroundColor Cyan
Write-Host (T 'ICDnlLXkv6HvvJrlrablj7dAZHjvvIzkvovlpoLvvJoxMjM0NTY3ODkwQGR4') -ForegroundColor Cyan
Write-Host (T 'ICDogZTpgJrvvJrlrablj7dAbHTvvIzkvovlpoLvvJoxMjM0NTY3ODkwQGx0') -ForegroundColor Cyan
Write-Host (T 'ICDnp7vliqjvvJrlrablj7dAY21jY++8jOS+i+Wmgu+8mjEyMzQ1Njc4OTBAY21jYw==') -ForegroundColor Cyan
Write-Host ""

$Account = Read-RequiredText -Prompt (T '6K+36L6T5YWl5qCh5Zut572R6LSm5Y+3') -Example "2300000000@cmcc"
$SecurePassword = Read-Host (T '6K+36L6T5YWl5qCh5Zut572R5a+G56CB') -AsSecureString
$Password = Convert-SecureStringToPlainText $SecurePassword

if (-not $Password) {
    throw (T '5a+G56CB5LiN6IO95Li656m644CC')
}

$configObject = Get-Content -LiteralPath $Template -Raw -Encoding UTF8 | ConvertFrom-Json
$configObject.username = $Account
$configObject.password = $Password
$configObject | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Config -Encoding UTF8

Write-Host ""
Write-Host (T '5bey55Sf5oiQIGNvbmZpZy5qc29u44CC') -ForegroundColor Green
Write-Host (T '5q2j5Zyo5rWL6K+V6L+e5o6lIFdpLUZpIOW5tueZu+W9leOAguWmguaenOW3sue7j+WcqOe6v++8jOiEmuacrOS8muiHquWKqOi3s+i/h+eZu+W9leOAgg==') -ForegroundColor Cyan
Write-Host ""

& powershell -ExecutionPolicy Bypass -File $RunnerScript -Python $Python
$TestExitCode = $LASTEXITCODE

Write-Host ""
if ($TestExitCode -eq 0) {
    Write-Host (T '5rWL6K+V5a6M5oiQ44CC5Y+v5Lul5a6J6KOFIFdpbmRvd3Mg55m75b2V5ZCO6Ieq5Yqo6L+Q6KGM55qE5Lu75Yqh44CC') -ForegroundColor Green
}
else {
    Write-Host (T '5rWL6K+V5pyq5oiQ5Yqf44CC5aaC5p6c5Y+q5piv5qCh5Zut572R5b2T5YmN562W55Wl6ZmQ5Yi25LiK572R77yM5Lmf5Y+v57un57ut5a6J6KOF5Lu75Yqh44CC') -ForegroundColor Yellow
}

$answer = Read-Host (T '546w5Zyo5a6J6KOF6Ieq5Yqo55m75b2V5Lu75Yqh5ZCX77yf6L6T5YWlIFkg57un57ut77yM5YW25LuW5Lu75oSP6ZSu6Lez6L+H')
if ($answer -match '^[Yy]$') {
    & powershell -ExecutionPolicy Bypass -File $Installer -TaskName $TaskName -Python $Python
    if ($LASTEXITCODE -ne 0) {
        throw (T '5a6J6KOF6K6h5YiS5Lu75Yqh5aSx6LSl44CC')
    }
    Write-Host ""
    Write-Host (T '5a6M5oiQ44CC5Lul5ZCOIFdpbmRvd3Mg55m75b2V5ZCO5Lya6Ieq5Yqo5bCd6K+V55m75b2V5qCh5Zut572R44CC') -ForegroundColor Green
}
else {
    Write-Host (T '5bey6Lez6L+H6Ieq5Yqo5Lu75Yqh5a6J6KOF44CC5Lul5ZCO5Y+v5omL5Yqo6L+Q6KGMIGluc3RhbGxfc3RhcnR1cF90YXNrLnBzMeOAgg==') -ForegroundColor Yellow
}

Write-Host ""
Write-Host (T '5o+Q56S677yaY29uZmlnLmpzb24g5Lya5L+d5a2Y6LSm5Y+35ZKM5a+G56CB77yM6K+35LiN6KaB5Y+R57uZ5Yir5Lq644CC') -ForegroundColor Yellow
