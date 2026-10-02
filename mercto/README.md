# Qadiyati (قضيتي) - local development

This workspace contains one FastAPI backend and three Flutter clients: Customer, Super Admin, and Tenant Dashboard. The customer app's API contract is the source of truth.

## Start the backend (Windows PowerShell)

```powershell
cd C:\Users\PC\OneDrive\Desktop\mercato_super\mercto
.\start_backend.ps1
```

The unified server uses port 8001 so it can run alongside an older customer-only server on port 8000. Health check: `http://localhost:8001/health`; API docs: `http://localhost:8001/docs`. Use `start_all_apps.ps1` to launch the backend and all three clients together.

Development OTP is `123456`. The configured Super Admin phone is `+218915750694`. Register that number in the Customer app and verify it with the development OTP; use the same phone and password in Super Admin. Real SMS delivery is not configured.

## Run clients

Start each command in a separate PowerShell window while the backend remains running:

```powershell
cd C:\Users\PC\OneDrive\Desktop\mercato_super\mercto\mercato_customer_app_flutter
flutter pub get
flutter run
```

```powershell
cd C:\Users\PC\OneDrive\Desktop\mercato_super\mercto\mercato_super_admin_dashboard_flutter\super_admin_dashboard
flutter pub get
flutter run -d chrome
```

```powershell
cd C:\Users\PC\OneDrive\Desktop\mercato_super\mercto\mercato_tenant_dashboard_flutter\tenant_dashboard
flutter pub get
flutter run -d chrome
```

Web uses `localhost`; Android Emulator uses `10.0.2.2`. For a physical phone, use the PC's LAN IPv4 and allow inbound TCP port 8001 in Windows Firewall:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8001/api/v1
```

Replace the sample IP. iOS builds require macOS and Xcode; use the same `API_BASE_URL` define with an address reachable from the iPhone. Location permission is needed for GPS; the map can also be moved and tapped manually. Map tiles need internet access.

## Database

The default development database is `mercato_customer_app_flutter/backend/mercato.db` (SQLite). Open it with DB Browser for SQLite. Important relationships: `stores.owner_id -> users.id`, `products.store_id -> stores.id`, `products.category_id -> categories.id`, `orders.user_id -> users.id`, `orders.store_id -> stores.id`, `order_items.order_id -> orders.id`, and `addresses.user_id -> users.id`. Existing SQLite databases receive additive schema updates at backend startup. Back up the database before production upgrades; do not delete it to fix app issues.

## Checks

Backend tests: `python -m pytest tests -q` from `mercato_backend_updated\backend`. Flutter checks/builds are run separately in each app directory.

For production configure strong `JWT_SECRET` and `OTP_SECRET`, HTTPS, CORS, and an SMS provider. Never use the development OTP or placeholder secrets in production.
