# خادم المول الرقمي (Python)

الخادم مبني بـ **FastAPI** و**SQLAlchemy**. يستخدم SQLite للتطوير المحلي، ويمكن تحويله إلى PostgreSQL بتغيير `DATABASE_URL`.

## التشغيل على Windows

```powershell
cd backend
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item .env.example .env
python run.py
```

افتح `http://127.0.0.1:8000/docs` لتجربة واجهات API. في وضع التطوير رمز OTP هو `123456` ويظهر أيضًا في سجل الخادم. هذا للتطوير فقط؛ لا تعرض الرمز في الإنتاج، واربط مزود SMS ليبيًا قبل الإطلاق.

## توصيل تطبيق Android

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

للهاتف الحقيقي استخدم عنوان IP المحلي للكمبيوتر واجعل الجهازين على الشبكة نفسها. بناء إصدار iOS النهائي يحتاج macOS.

## أهم الواجهات

- `POST /api/v1/auth/request-otp` و`POST /api/v1/auth/verify-otp`
- `GET /api/v1/stores` و`GET /api/v1/stores/{slug}` و`GET /api/v1/categories`
- `POST /api/v1/stores/applications` و`GET/PATCH /api/v1/vendor/store`
- `GET/POST/PATCH/DELETE /api/v1/vendor/products`
- `GET/POST /api/v1/cart/items` و`POST /api/v1/cart/checkout`
- `GET /api/v1/orders/me` وواجهات طلبات البائع والإدارة
- `GET /api/v1/admin/store-applications` و`PATCH /api/v1/admin/stores/{id}/review`

إتمام السلة ينشئ طلبًا مستقلًا لكل متجر. صلاحيات البائع مفروضة في الخادم.

## حساب مدير التطوير

غيّر `ADMIN_PHONE` في `.env` إلى الرقم المخصص للإدارة. عند التحقق من OTP لذلك الرقم ينشأ الحساب بدور `ADMIN`. غيّر أسرار JWT وOTP قبل أي تشغيل خارج التطوير.


### Password authentication
- Registration: request OTP, then verify it with `full_name`, `password`, `terms_accepted: true`, and optional `invite_code`.
- Password login: `POST /api/v1/auth/login` with `phone` and `password`.
- Password reset: request OTP, then `POST /api/v1/auth/reset-password` with `phone`, `code`, and `new_password`.
- Passwords are stored as salted scrypt hashes. Invite codes are currently recorded on the account; invitation issuance and validity checks are not implemented.
