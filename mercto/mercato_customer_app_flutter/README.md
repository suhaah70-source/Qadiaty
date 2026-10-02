# المول الرقمي

منصة ليبية متعددة المتاجر. تطبيق الزبون مكتوب بـ Flutter وDart، والخادم الخلفي مكتوب بـ Python وFastAPI. يستخدم الخادم SQLite محليًا، ويدعم PostgreSQL للإنتاج.

## تشغيل الخادم

في PowerShell:

```powershell
cd backend
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item .env.example .env
python run.py
```

توثيق API التفاعلي متاح على `http://127.0.0.1:8000/docs`. في وضع التطوير رمز OTP هو `123456`؛ يظهر كذلك في سجل الخادم. إرسال SMS الحقيقي غير مربوط بعد.

لتعيين رقم مدير المنصة، عدّل `ADMIN_PHONE` في `backend/.env`. أول تسجيل وتحقق لهذا الرقم ينشئ حسابًا بدور الإدارة. غيّر أسرار JWT وOTP قبل تشغيل أي بيئة مشتركة.

## تشغيل تطبيق الزبون

في نافذة PowerShell ثانية من مجلد المشروع:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

العنوان `10.0.2.2` مخصص لمحاكي Android للوصول إلى الخادم العامل على الكمبيوتر. للهاتف الحقيقي استخدم عنوان IP المحلي للكمبيوتر. يتطلب الاتصال عبر HTTP إذن cleartext في نسخة Debug فقط؛ استخدم HTTPS في النشر.

## ما تدعمه النسخة البرمجية الحالية

- الدخول وإنشاء الحساب برقم الهاتف ورمز OTP.
- عرض المتاجر المقبولة والمنتجات والتصنيفات.
- سلة متعددة المتاجر تُنشئ طلبًا فرعيًا لكل متجر.
- الدفع عند الاستلام، حفظ عنوان التوصيل، وتتبع حالات الطلب.
- API لطلب فتح متجر، وتخصيص الهوية، وإدارة المنتجات والطلبات.
- API لإدارة قبول المتاجر والتصنيفات والبانرات والطلبات بصلاحيات الإدارة.
- شاشات أولية لطلب فتح متجر ولوحة البائع ولوحة مدير المنصة داخل تطبيق Flutter.

رسائل SMS المحلية الفعلية، الدفع الإلكتروني، ورفع الصور إلى تخزين سحابي تحتاج ربط مزوداتها قبل الإطلاق. لوحات ويب مستقلة للبائع والإدارة غير موجودة حاليًا؛ الشاشات الأولية مدمجة داخل تطبيق Flutter.

## هيكل الملفات

```text
mercato_customer_app_flutter/
├── lib/                       # تطبيق الزبون Flutter / Dart
│   ├── core/                  # إعداد API والثيم والعملاء المشتركين
│   ├── models/                # نماذج المتاجر والمنتجات والطلبات
│   ├── providers/             # حالة الدخول والسلة
│   └── screens/               # صفحات التطبيق
├── backend/                   # الخادم الخلفي Python
│   ├── app/
│   │   ├── config.py          # إعدادات البيئة
│   │   ├── database.py        # SQLAlchemy وSQLite/PostgreSQL
│   │   ├── models.py          # المستخدمون والمتاجر والطلبات
│   │   ├── schemas.py         # مخططات الطلبات والتحقق
│   │   ├── security.py        # OTP وJWT وتطبيع رقم الهاتف
│   │   └── main.py            # واجهات FastAPI والصلاحيات
│   ├── requirements.txt
│   ├── .env.example
│   ├── run.py
│   └── README.md
├── assets/                    # أصول تطبيق الهاتف
├── android/                   # إعدادات Android
├── ios/                       # إعدادات iOS
├── pubspec.yaml
└── README.md
```

## ملاحظات النشر

- SQLite للاستخدام المحلي والتجربة الفردية؛ استخدم PostgreSQL في بيئة الإنتاج.
- OTP الثابت وطباعة الرمز مخصصان للتطوير. إعداد الإنتاج يوقف إرسال OTP إلى أن يُربط مزود SMS.
- اربط ملفات الصور بخدمة تخزين مناسبة، ولا تحفظ مفاتيح الخدمات داخل الشيفرة.
- بناء تطبيق iOS وتوقيعه يحتاج جهاز macOS.




Account creation and sign-in now use the visual phone/password forms. Registration verifies the phone by OTP, stores a salted password hash and terms acceptance, and password login/reset use the Python API (`/auth/login`, `/auth/reset-password`). Invite codes are captured for future referral validation but are not validated against an issuance system yet.
