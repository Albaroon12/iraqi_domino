# دليل النشر والإطلاق النهائي — تطبيق المقهى (`Al-Maqha` v1.0)

## 1. تشغيل ورفع السيرفر ولوحة التحكم (`/admin`)
- **التشغيل المحلي للتجربة**:
  ```powershell
  dart run bin/server.dart
  ```
  ثم افتح لوحة التحكم الشاملة من المتصفح: `http://localhost:8080/admin`
- **الرفع على الاستضافة (Railway / Render / VPS عبر Docker)**:
  يوجد ملف `Dockerfile` جاهز في جذر المشروع يبني ملف تنفيذي أصلي سريع (`domino_server`).
  اضبط متغيرات البيئة التالية في الاستضافة:
  - `PORT=8080`
  - `DOMINO_DB_PATH=/data/server_accounts.json`
  - `ADMIN_SECRET=ضع_كلمة_سر_قوية_خاصة_بك_هنا`

## 2. بناء نسخة الإنتاج للأندرويد (Google Play AAB / APK)
مرر رابط السيرفر الخاص بك عبر `--dart-define=MAQHA_SERVER_URL`:
```powershell
flutter build appbundle --release --dart-define=MAQHA_SERVER_URL=https://your-server-domain.com
flutter build apk --release --dart-define=MAQHA_SERVER_URL=https://your-server-domain.com
```

## 3. بناء نسخة الإنتاج للآيفون (Apple App Store IPA على macOS)
```bash
flutter build ipa --release --dart-define=MAQHA_SERVER_URL=https://your-server-domain.com
```

## 4. متطلبات المتاجر المدمجة جاهزاً داخل التطبيق
- حذف الحساب الذاتي من داخل الإعدادات (`POST /api/account/delete-self`).
- شاشة الخصوصية وإقرار العملة الافتراضية غير النقدية (`AboutLegalScreen`).
- دعم العمل الكامل بدون إنترنت (ضد الكمبيوتر + اللعب المحلي) تلقائياً عند انقطاع الشبكة.
