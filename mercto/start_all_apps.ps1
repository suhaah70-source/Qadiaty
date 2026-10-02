$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$apiPort = if ($env:PORT) { [int]$env:PORT } else { 8001 }
$apiBaseUrl = "http://localhost:$apiPort/api/v1"

function Test-UnifiedApi {
    try {
        $spec = Invoke-RestMethod -Uri "http://localhost:$apiPort/openapi.json" -TimeoutSec 3
        $paths = $spec.paths.PSObject.Properties.Name
        return ($paths -contains '/api/v1/me/tenants') -and
            ($paths -contains '/api/v1/admin/analytics') -and
            ($paths -contains '/api/v1/auth/login') -and
            ($paths -contains '/api/v1/admin/overview')
    } catch {
        return $false
    }
}

if (-not (Test-UnifiedApi)) {
    $backendCommand = "& '$root\start_backend.ps1'"
    Start-Process -FilePath 'powershell.exe' -WindowStyle Normal -WorkingDirectory $root `
        -ArgumentList @('-NoExit', '-ExecutionPolicy', 'Bypass', '-Command', $backendCommand)

    $ready = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        Start-Sleep -Seconds 1
        if (Test-UnifiedApi) {
            $ready = $true
            break
        }
    }
    if (-not $ready) {
        throw "The unified API did not start on port $apiPort. Check the backend window."
    }
}

$apps = @(
    @{ Name = 'Customer app'; Path = 'mercato_customer_app_flutter'; Port = 5100 },
    @{ Name = 'Super admin'; Path = 'mercato_super_admin_dashboard_flutter\super_admin_dashboard'; Port = 5101 },
    @{ Name = 'Tenant dashboard'; Path = 'mercato_tenant_dashboard_flutter\tenant_dashboard'; Port = 5102 }
)

foreach ($app in $apps) {
    $appPath = Join-Path $root $app.Path
    if (-not (Test-Path -LiteralPath (Join-Path $appPath 'pubspec.yaml'))) {
        throw "Flutter app project not found: $appPath"
    }
    $flutterCommand = "flutter run -d chrome --web-port $($app.Port) --dart-define=API_BASE_URL=$apiBaseUrl"
    Start-Process -FilePath 'powershell.exe' -WindowStyle Normal -WorkingDirectory $appPath `
        -ArgumentList @('-NoExit', '-ExecutionPolicy', 'Bypass', '-Command', $flutterCommand)
    Start-Sleep -Milliseconds 700
}

Write-Host 'Started the customer app, super admin, tenant dashboard, and their shared API.'