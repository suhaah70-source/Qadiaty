$ErrorActionPreference = 'Stop'
$backendPath = Join-Path $PSScriptRoot 'mercato_backend_updated\backend'
$apiPort = if ($env:PORT) { [int]$env:PORT } else { 8001 }

if (-not $env:ADMIN_PHONE) {
    $env:ADMIN_PHONE = '+218915750694'
}
if (-not $env:APP_ENV) {
    $env:APP_ENV = 'development'
}

$listeners = netstat -ano | Select-String (":$apiPort\s+.*LISTENING")
if ($listeners) {
    throw "Port $apiPort is already in use. Choose another PORT or stop the API using that port."
}

$python = Join-Path $backendPath '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    $python = Join-Path $PSScriptRoot 'mercato_customer_app_flutter\backend\.venv\Scripts\python.exe'
}
if (-not (Test-Path -LiteralPath $python)) {
    $python = (Get-Command python -ErrorAction Stop).Source
}

Push-Location $backendPath
try {
    $env:PORT = "$apiPort"
    Write-Host "Starting the unified API (customer app + tenant dashboard + super admin) at http://localhost:$apiPort"
    Write-Host "API docs: http://localhost:$apiPort/docs"
    & $python run.py
} finally {
    Pop-Location
}