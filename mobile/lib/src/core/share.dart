// المشاركة: ما يُكتب في رسالة واتساب حين يضغط أحدُهم «شارك».
//
// ── أربعةُ قراراتٍ تستحقّ أن تُقرأ ────────────────────────────────────────────
//
// **١) النصُّ يُبنى هنا لا في الشاشة، ويُسأل بلا جهاز.** ما يُبنى داخل
// `onPressed` لا يُقاس إلّا بفتح واتساب على جوالٍ حقيقيّ، فلا يُقاس. وهذه
// دوالُّ صافية: تأخذ خدمةً وتُعيد نصّاً، فتُسأل في ملّي ثانية.
//
// **٢) والرابطُ من القاعدة لا من الشيفرة.** اليوم هو صفحةُ الإصدار، وغداً
// متجرُ Play، وبعدَه صفحةٌ على الوِب. ولو كُتب في الشيفرة لَاحتاج كلُّ تبديلٍ
// نسخةً جديدةً من التطبيق تُنشَر ثمّ ينتظر الناسُ حتى يحدّثوا — والذين لا
// يحدّثون يرسلون رابطاً ميّتاً إلى أهلهم شهوراً.
//
// **٣) ولا رابطَ مكسورٌ أبداً.** إن لم يُضبط الرابط بعدُ، أو ضُبط بما ليس
// `https://`، فالرسالةُ تخرج بلا سطر الرابط أصلاً. ورسالةٌ فيها «حمّل التطبيق
// من:» ثمّ فراغٌ أسوأ من رسالةٍ بلا دعوة: تُقرأ عطباً في التطبيق الذي تدعو
// إليه.
//
// **٤) ولا يُشارَك ما ليس للعلن.** رقمُ مقدّم الخدمة وبريدُه لا يخرجان في
// نصٍّ يُعاد إرسالُه من يدٍ إلى يد — وصاحبُهما لم يأذن بذلك حين سجّل. وما
// يُشارَك هو ما تراه أصلاً في صفحة الخدمة العامّة.
library;

import '../data/models.dart';
import 'format.dart';

/// رابطُ الدعوة المخبوز في الحزمة — يُملأ عند البناء بصفحة إصدارات المستودع.
///
/// **وهو احتياطٌ لا بديل.** الأصلُ `app_settings.share_url` يضعه صاحبُ
/// المنصّة فيُبدَّل بلا تحديثِ تطبيق. لكنّ ما لم يُضبط بعدُ كان يُخرج
/// الرسائلَ بلا سطر دعوةٍ أصلاً — **فيصل الخبرُ إلى من لا يعرف من أين
/// يأتي بالتطبيق**، وهو ما وقع فعلاً في أوّل رسالةٍ خرجت.
///
/// فصار البناءُ يخبز رابطَ صفحة الإصدارات، فلا تخرج رسالةٌ بلا باب. وأوّلُ
/// قيمةٍ تُوضع في القاعدة تعلو عليه.
const shareUrlFallback = String.fromEnvironment('SHARE_URL');

/// أوّلُ رابطٍ صالحٍ من الاثنين — القاعدةُ أوّلاً ثمّ المخبوز.
String pickShareUrl(String fromDatabase) =>
    isShareUrlValid(fromDatabase) ? fromDatabase.trim() : shareUrlFallback;

/// أعلى ما يُقبل من طول الرسالة.
///
/// **ورسالةٌ طويلةٌ تُطوى في واتساب خلف «قراءة المزيد»**، فيضيع سطرُ الرابط
/// وهو المقصود. فيُقصَّر الوصفُ ويبقى ما يدلّ.
const shareMaxDescription = 140;

/// هل يصلح هذا رابطاً يُرسَل إلى الناس؟
///
/// والقاعدةُ نفسُها المكتوبة على `app_versions.download_url`: `https://` أو
/// لا شيء. و`http://` عاريةً تُنذر في المتصفّحات الحديثة، ورابطٌ يُنذر في
/// رسالةِ دعوةٍ يُقرأ احتيالاً.
bool isShareUrlValid(String url) {
  final u = url.trim();
  if (u.isEmpty) return false;
  if (!u.startsWith('https://')) return false;
  // `https://` وحدها بلا مضيف.
  if (u.length <= 'https://'.length) return false;
  return !u.contains(' ');
}

/// سطرُ الدعوة — أو لا شيء إن لم يكن ثَمّ رابطٌ صالح.
String _invite(String url) =>
    isShareUrlValid(url) ? '\n\nحمّل تطبيق فرحتي:\n${url.trim()}' : '';

/// يقصّ النصَّ عند حدٍّ بلا أن يقطع كلمةً في نصفها.
String _clip(String text, int max) {
  final clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (clean.length <= max) return clean;
  final cut = clean.substring(0, max);
  final space = cut.lastIndexOf(' ');
  return '${(space > max ~/ 2 ? cut.substring(0, space) : cut).trimRight()}…';
}

/// السعرُ كما يُقرأ: مبلغٌ واحدٌ أو مدى.
String shareServicePrice(ServiceItem item) => item.priceTo == null
    ? formatMoney(item.price)
    : '${formatMoney(item.price)} – ${formatMoney(item.priceTo!)}';

/// نصُّ مشاركة خدمة.
///
/// وترتيبُ السطور مقصود: الاسمُ أوّلاً لأنّه ما يُقرأ في معاينة الرسالة،
/// ثمّ من يقدّمها وأين، ثمّ السعر — وهو أوّلُ ما يُسأل عنه.
String shareTextForService(ServiceItem item, {required String url}) {
  final lines = <String>[
    '✨ ${item.title.trim()}',
    '${item.categoryName} — ${item.providerName}',
    if (item.providerGovernorate.trim().isNotEmpty) '📍 ${item.providerGovernorate}',
    '💰 ${shareServicePrice(item)}${item.unit.trim().isEmpty ? '' : ' / ${item.unit}'}',
  ];

  final about = _clip(item.description, shareMaxDescription);
  if (about.isNotEmpty) lines.addAll(['', about]);

  return '${lines.join('\n')}${_invite(url)}';
}

/// نصُّ مشاركة ملفّ مقدّم خدمة.
String shareTextForProvider({
  required String name,
  required String governorate,
  required num rating,
  required int reviewsCount,
  required String about,
  required String url,
}) {
  final lines = <String>[
    '✨ ${name.trim()}',
    if (governorate.trim().isNotEmpty) '📍 ${governorate.trim()}',
    // **ولا تُعرض نجومٌ لمن لا تقييمَ له.** «٠٫٠ من ٥» تُقرأ رداءةً، وهو
    // إنّما لم يُقيَّم بعد — وهذا ظلمٌ يقع في نصٍّ يُعاد إرسالُه.
    if (reviewsCount > 0)
      // و`reviewForms` هي صيغُ العدد نفسُها المستعملة في الشاشات — فلا
      // يُقال «٣ تقييمات» هنا و«٣ تقييماً» هناك.
      '⭐ ${rating.toStringAsFixed(1)} (${formatCount(reviewsCount, reviewForms)})',
  ];

  final blurb = _clip(about, shareMaxDescription);
  if (blurb.isNotEmpty) lines.addAll(['', blurb]);

  return '${lines.join('\n')}${_invite(url)}';
}

/// نصُّ مشاركة التطبيق نفسِه.
///
/// **وهذه تُشارَك بلا سياق**، فتقول ما هو التطبيق لا اسمَه وحده: من يصله
/// «فرحتي» ورابطٌ لا يعرف أيَشتري به أم يقرأ.
String shareTextForApp({required String url}) {
  const pitch = 'فرحتي — كل خدمات زفافك في مكان واحد.\n'
      'قاعات، تصوير، تجميل، ضيافة… تحجز من جوالك.';
  final invite = _invite(url);
  // **وبلا رابطٍ لا معنى لمشاركة التطبيق أصلاً**، فيُعاد نصٌّ فارغٌ ويُخفي
  // الزرَّ من يعرضه. ومشاركةُ الخدمة تبقى نافعةً بلا رابط (اسمٌ وسعرٌ ومقدّم).
  return invite.isEmpty ? '' : '$pitch$invite';
}
