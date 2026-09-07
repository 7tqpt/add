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

// ── تقييدُ البطّاريّة ────────────────────────────────────────────────────────
//
// **وهو أشهرُ سببٍ لـ«لا يصلني إشعارٌ والتطبيق مغلق».** أندرويد يُدخل
// التطبيقاتِ في سُبات Doze، وأجهزةُ إنفينكس وتكنو وشاومي وأوبو — وهي أكثرُ
// ما يُستعمل هنا — تزيد فوقه قتلاً للخلفيّة أشدَّ من قياسيّ أندرويد.
// والمقيَّدُ لا يستيقظ لرسالة FCM حتى تُفتح شاشتُه.
//
// **ولا تُصلحه شيفرة.** الإعفاءُ بيد صاحب الجهاز وحدَه، وأقصى ما نملكه أن
// نقول له إنّ التطبيق مقيَّدٌ وأن نفتح له الموضع.

typedef BatteryProbe = Future<bool> Function();

/// أمُعفىً التطبيقُ من تقييد البطّاريّة؟
///
/// **وحيث لا جسرَ يُقرأ «معفىً» لا «مقيَّد».** على iOS لا تقييدَ من هذا
/// النوع، ولو قُرئ الغيابُ تقييداً لَظهر لكلّ صاحب آيفون تحذيرٌ عن شاشةٍ لا
/// وجودَ لها في جهازه.
BatteryProbe batteryProbe = _batteryUnrestricted;
BatteryProbe batterySettingsOpener = _openBatterySettings;

void resetBatteryBridge() {
  batteryProbe = _batteryUnrestricted;
  batterySettingsOpener = _openBatterySettings;
}

Future<bool> _batteryUnrestricted() => _ask('batteryUnrestricted', whenAbsent: true);
Future<bool> _openBatterySettings() => _ask('openBatterySettings', whenAbsent: false);

Future<bool> _ask(String method, {required bool whenAbsent}) async {
  try {
    final ok = await notificationBridge.invokeMethod<bool>(method);
    return ok ?? whenAbsent;
  } on PlatformException {
    return whenAbsent;
  } on MissingPluginException {
    return whenAbsent;
  }
}
