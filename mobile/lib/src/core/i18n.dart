// اللغة: العربيّة والإنجليزيّة.
//
// ── ثلاثةُ قراراتٍ تستحقّ أن تُقرأ ──────────────────────────────────────────
//
// **١) والمفتاحُ هو النصُّ العربيُّ نفسُه، لا رمزٌ مخترَع.**
//
// المعتادُ في التدويل مفاتيحُ مثل `booking.confirm.title`. وهي أصلحُ لتطبيقٍ
// يُبنى من أوّله، وأسوأُ لتطبيقٍ **قائمٍ** فيه ثمانمئةُ نصٍّ عربيّ: كلُّ نصٍّ
// يحتاج اسماً يُخترع ويُتفق عليه ويُراجَع، وخطأٌ في اسمٍ واحد يُظهر
// `booking.confrm.title` على الشاشة أمام صاحبها.
//
// وبالنصّ العربيّ مفتاحاً: الترجمةُ الناقصةُ تُعرض **بالعربيّة** — وهي لغةُ
// التطبيق الأصليّة وأهلِه. فأسوأُ ما يقع أن يرى الإنجليزيُّ كلمةً عربيّة، لا
// أن يرى رمزاً لا يفهمه أحد.
//
// **٢) والاختيار يُحفظ في الجهاز لا في الحساب.** شاشةُ الدخول نفسُها تحتاج
// لغةً قبل أن يكون هناك حساب، ومن بدّل اللغةَ ثمّ أعاد فتح التطبيق يجدها كما
// تركها ولو لم يسجّل بعد.
//
// **٣) والاتّجاه يتبع اللغة.** العربيّةُ من اليمين والإنجليزيّةُ من اليسار،
// وMaterialApp يقلب الشجرةَ كلَّها تبعاً لـ`locale` — فلا `Directionality`
// تُكتب بيدٍ في شاشة.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings_en.dart';

enum AppLocale { ar, en }

/// اللغةُ الحاليّة — تُستمع إليها في الجذر فتُعاد الشجرةُ عند التبديل.
final appLocale = ValueNotifier<AppLocale>(AppLocale.ar);

const _prefKey = 'app_locale';

/// يقرأ اللغةَ المحفوظة عند الإقلاع.
///
/// **ولا يرمي إن تعذّرت القراءة.** تخزينُ الجهاز قد يُمنع أو يمتلئ، وتطبيقٌ
/// لا يُقلع لأجل تفضيلِ لغةٍ عطبٌ أكبرُ من الذي يتجنّبه. فتبقى العربيّة.
Future<void> loadLocale() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved == 'en') appLocale.value = AppLocale.en;
  } catch (_) {
    // العربيّةُ هي الأصل، وهي ما يبقى.
  }
}

/// يبدّل اللغةَ ويحفظها.
Future<void> setLocale(AppLocale value) async {
  appLocale.value = value;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, value == AppLocale.en ? 'en' : 'ar');
  } catch (_) {
    // بُدّلت في الشاشة ولم تُحفظ: تعود عند الإقلاع القادم، ولا شيءَ ينكسر.
  }
}

/// يترجم نصّاً عربيّاً إلى لغة الشاشة الحاليّة.
///
/// وفي العربيّة يعيده كما هو بلا بحث. وفي الإنجليزيّة يبحث عنه، فإن لم يجده
/// **أعاد العربيّ** — وهو أهونُ من فراغٍ أو رمز.
String tr(String arabic) {
  if (appLocale.value == AppLocale.ar) return arabic;
  return englishStrings[arabic] ?? arabic;
}

/// يترجم نصّاً فيه قيمةٌ تُدرَج: `trf('حُذف {0}', name)`.
///
/// **ونائبٌ مرقَّمٌ لا لصقٌ للأجزاء.** «حُذف $name» يصير في الإنجليزيّة
/// `$name deleted` — والترتيبُ يختلف بين اللغتين، فلا يُبنى النصُّ بالجمع.
String trf(String arabic, List<String> args) {
  var out = tr(arabic);
  for (var i = 0; i < args.length; i++) {
    out = out.replaceAll('{$i}', args[i]);
  }
  return out;
}

/// الـ`Locale` الذي يُعطى لـ`MaterialApp`.
Locale localeOf(AppLocale value) =>
    Locale(value == AppLocale.en ? 'en' : 'ar');

/// اسمُ اللغة بلغتها هي — «العربية» و«English».
///
/// **وبلغتها لا بلغة الشاشة:** من يبحث عن الإنجليزيّة في شاشةٍ عربيّة يبحث عن
/// كلمة `English` لا عن «الإنجليزية». وهذا عرفُ كلّ مبدّلِ لغةٍ يعرفه الناس.
String localeName(AppLocale value) =>
    value == AppLocale.en ? 'English' : 'العربية';
