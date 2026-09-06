// نغمةُ الإشعار: فتحُ الشاشة التي تُختار منها.
//
// ── ولماذا لا يختارها التطبيق ────────────────────────────────────────────────
//
// **أندرويد لا يُبدّل نغمةَ قناةٍ بعد إنشائها.** يقرأ التبديلَ ويتجاهله بلا
// خطأ — بتصميمٍ مقصود: ما إن تُنشأ القناة يصير الصوتُ والاهتزازُ والأولويّة
// ملكَ صاحب الجهاز، لا ملكَ التطبيق. فلا سبيل إلى «اختر نغمةً من داخل
// التطبيق» على أندرويد ٨ فما فوق، ولو كُتبت شاشةُ اختيارٍ جميلةٌ هنا لَما
// غيّرت شيئاً — وهذا أسوأ من ألّا تكون.
//
// فالمُتاحُ أن يُفتح له الموضعُ الصحيح في إعدادات جهازه، وفيه نغماتُ جواله
// كلُّها.
library;

import 'package:flutter/services.dart';

/// جسرُ الشيفرة الأصليّة — الاسمُ نفسُه المكتوب في `MainActivity.kt`.
///
/// **واسمٌ هنا واسمٌ هناك يعني جسراً لا يعبر أحد.** ولا يظهر ذلك إلّا على
/// جهازٍ حقيقيّ، فيُقاس تطابقُهما في الاختبار.
const notificationBridge = MethodChannel('ye.aras.aras/notifications');

/// ما ينفّذ الفتحَ فعلاً — يُبدَّل في الاختبار.
typedef ToneOpener = Future<bool> Function();

ToneOpener toneOpener = _openChannelSettings;

/// يُعيد المقبضَ إلى النظام — يُنادى في `tearDown`.
void resetToneOpener() => toneOpener = _openChannelSettings;

Future<bool> _openChannelSettings() async {
  try {
    final ok = await notificationBridge.invokeMethod<bool>('openChannelSettings');
    return ok ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    // iOS، أو نسخةٌ من التطبيق بلا الجسر — ليس عطباً يُعرض.
    return false;
  }
}

/// يفتح شاشةَ نغمة الإشعار.
///
/// يُعيد `false` إن تعذّر، فيسقط النداءُ إلى إعدادات التطبيق العامّة — وهي
/// أبعدُ بضغطتين لكنّها تصل.
Future<bool> openNotificationTone() => toneOpener();
