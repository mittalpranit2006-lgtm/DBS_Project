param([int]$Port = 0, [switch]$RollbackTestMode)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
if (Test-Path -LiteralPath 'local-config.ps1') { . .\local-config.ps1 }
if ($Port -gt 0) { $env:SVR_HTTP_PORT = [string]$Port }
if ($RollbackTestMode) { $env:SVR_TEST_MODE = 'true' }
if (-not $env:SVR_DB_URL -or $env:SVR_DB_USER -ne 'SVR_APP') {
    throw 'Set SVR_DB_URL and SVR_DB_USER=SVR_APP in environment or local-config.ps1.'
}
$portNumber = [int]$env:SVR_HTTP_PORT
if ($portNumber -lt 1 -or $portNumber -gt 65535) { throw 'SVR_HTTP_PORT must be 1–65535.' }
$java = 'C:\Program Files\Java\jdk-21.0.11\bin\java.exe'
if (-not (Test-Path -LiteralPath $java) -or -not (Test-Path -LiteralPath 'target/classes') -or -not (Test-Path -LiteralPath 'target/dependency')) {
    throw 'Java build is missing. Run the documented Maven build before startup.'
}
$listener = [Net.Sockets.TcpClient]::new()
try {
    $pending = $listener.BeginConnect('127.0.0.1', $portNumber, $null, $null)
    if ($pending.AsyncWaitHandle.WaitOne(300)) { $listener.EndConnect($pending); throw "Port $portNumber is already in use." }
} catch [Net.Sockets.SocketException] { }
finally { $listener.Dispose() }
if (-not $env:SVR_DB_PASSWORD) {
    $secure = Read-Host 'SVR_APP password (hidden)' -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { $env:SVR_DB_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr); $secure.Dispose() }
}
$diagnostics = "..\evidence\server-$portNumber-diagnostics.log"
try {
    & $java -cp 'target/classes;target/dependency/*' com.smartvehiclerental.Application 2>> $diagnostics
    if ($LASTEXITCODE -ne 0) { throw "Java server exited with code $LASTEXITCODE. See $diagnostics." }
} finally {
    Remove-Item Env:SVR_DB_PASSWORD -ErrorAction SilentlyContinue
    if ($RollbackTestMode) { Remove-Item Env:SVR_TEST_MODE -ErrorAction SilentlyContinue }
}
