# تجهيز نسخة Android — Football Stars 3D

## الحالة
أُضيف ملف `export_presets.cfg` وفيه إعداد Android تجريبي بمعرّف `com.footballstars3d.game` ودعم ARMv7 وARM64، كما أُضيف `BUILD_ANDROID.sh` لفحص المتطلبات وتشغيل التصدير. هذه حزمة مصدر جاهزة لمرحلة التصدير، **وليست APK**.

## المتطلبات
- Godot 4.2 أو أحدث، مع Export Templates المطابقة تماماً لإصدار المحرك.
- JDK متوافق مع إصدار Godot.
- Android SDK وAndroid Build-Tools.
- ضبط `JAVA_HOME` و`ANDROID_HOME` أو `ANDROID_SDK_ROOT`.

## إنشاء APK تجريبي
1. افتح `project.godot` في Godot.
2. افتح Editor Settings > Export > Android، وحدد مسارات Java SDK وAndroid SDK.
3. تأكد من تثبيت Export Templates المطابقة لإصدار Godot.
4. من الطرفية داخل مجلد المشروع شغّل: `./BUILD_ANDROID.sh`.
5. عند نجاح التصدير ستجد الملف في `build/FootballStars3D-debug.apk`.
6. انقل APK إلى الهاتف وثبّته بعد السماح بالتثبيت من مصدر موثوق.

## التوقيع والنشر
النسخة debug للاختبار. قبل النشر أنشئ مفتاح Release خاصاً بك واضبطه داخل إعدادات التصدير في Godot. لا تشارك ملف المفتاح أو كلمات مروره. غيّر معرّف الحزمة إذا كنت تملك نطاقاً أو معرّفاً خاصاً.

## ملاحظة الأداء
تم تفعيل GL Compatibility وتضمين معماريتي ARMv7 وARM64. يلزم اختبار FPS والحرارة واللمس على هاتف منخفض أو متوسط المواصفات قبل اعتبار النسخة جاهزة للنشر.

## ما لم يتم
في بيئة الإنشاء الحالية لا يوجد Godot أو Android SDK/adb؛ لذلك لم يتم تشغيل المحرك أو إنشاء APK أو تثبيته على هاتف. إعداد Export Preset مبدئي ويجب التحقق منه داخل نسخة Godot التي ستستخدمها.
