/// رقمُ الجوال: تطهيرٌ وفحصٌ — في موضعٍ واحدٍ تقرؤه الشاشاتُ الأربع.
///
/// ── ولماذا كُتب هذا ─────────────────────────────────────────────────────────
///
/// كان حقلُ الرقم يقبل **أيَّ شيءٍ غيرِ فارغ**. فسُجّل في ملفّ صاحب المنصّة
/// نفسِه `+96657671431` — مفتاحُ السعوديّة وبعده **ثمانِ خاناتٍ لا تسع** —
/// فلم يكن رقماً على أيّ شبكة. ولم يظهر ذلك حتى طُلب رمزُ تحقّقٍ فلم يجد إلى
/// أين يذهب.
///
/// **وهو أخطرُ ممّا يبدو:** الرقمُ هو ما يُتواصل به في كلّ حجز. فرقمٌ ناقصٌ
/// بخانةٍ يُحفظ صامتاً، ثمّ يتّصل به مقدّمُ الخدمة ليلةَ العرس فلا يجد أحداً —
/// ولا يعرف صاحبُه أنّ العلّةَ في خانةٍ سقطت منه يومَ سجّل.
///
/// ── وما يُطهَّر ─────────────────────────────────────────────────────────────
///
/// الفراغاتُ والشُّرَطُ والأقواس، والأرقامُ العربيّةُ والفارسيّة (من كتب بلوحةٍ
/// عربيّةٍ أخرج «٧٧٠…» وهي أرقامٌ لا تفهمها شبكةٌ ولا مُرسِل)، و`00` بدلَ
/// `+`، والصفرُ السابقُ في الرقم المحلّيّ.
///
/// **واليمنُ هو الافتراض:** من كتب `771234567` أو `0771234567` أراد `+967`.
///
/// ── وهذا الملفُّ صورةٌ لِما في دالّة الحافة ────────────────────────────────
///
/// `supabase/functions/phone-otp/index.ts` تُطهّر وتفحص المثلَ — **والخادمُ
/// هو الحكم**: الشاشةُ تُساعد من يكتب، ومن نادى الدالّةَ بلا شاشةٍ يُردّ
/// هناك. وتكرارُ المنطق في الطرفين مقصودٌ لا سهو: شاشةٌ بلا خادمٍ حرزٌ
/// وهميّ، وخادمٌ بلا شاشةٍ يردّ بعد أن يكتب المستخدمُ كلَّ شيء.
library;

/// أطوالُ الأرقام المحلّيّة التي نعرفها، ومفتاحُ كلٍّ.
///
/// **ولا يُحصَر العالمُ في اثنين:** ما جاء بمفتاحٍ آخر يُقاس بحدٍّ عامّ —
/// فمن يسجّل من مصرَ أو الأردنّ لا يُردّ لأنّنا لم نكتب بلدَه.
const _known = {
  '967': (length: 9, starts: '7'), // اليمن: تسعٌ تبدأ بـ7
  '966': (length: 9, starts: '5'), // السعوديّة: تسعٌ تبدأ بـ5
};

/// يُبدّل الأرقامَ العربيّةَ والفارسيّةَ ويُسقط ما ليس رقماً ولا `+`.
///
/// **ويُكتب المدى بنقاطه لا بحروفه.** كتبتُه أوّلَ مرّة `RegExp('[٠-٩]')`
/// فصار في الملفّ نصّاً عربيّاً — فعدّه حارسُ الترجمة نصَّ واجهةٍ بلا ترجمة
/// وأحمرَّت الحزمة. وهو صادقٌ في العدّ: لا يعرف المدى من الكلمة. والأصرحُ
/// أن يُقرأ الحدُّ رقماً: `0x0660` أوّلُ الأرقام العربيّة.
String _digits(String raw) {
  const arabicZero = 0x0660; // ٠
  const persianZero = 0x06F0; // ۰
  const asciiZero = 0x30;
  final out = StringBuffer();
  for (final code in raw.runes) {
    if (code >= arabicZero && code <= arabicZero + 9) {
      out.writeCharCode(code - arabicZero + asciiZero);
    } else if (code >= persianZero && code <= persianZero + 9) {
      out.writeCharCode(code - persianZero + asciiZero);
    } else if (code == 0x2B || (code >= asciiZero && code <= asciiZero + 9)) {
      // `+` ورقمٌ لاتينيّ — يبقيان.
      out.writeCharCode(code);
    }
    // وما عداه يُسقط: فراغٌ أو شرطةٌ أو قوسٌ أو علامةُ اتّجاهٍ خفيّة.
  }
  return out.toString();
}

/// يُعيد الرقمَ بصيغة `+‹مفتاح›‹رقم›`، أو `null` إن لم يكن رقماً صالحاً.
String? normalisePhone(String raw) {
  var s = _digits(raw);
  if (s.isEmpty) return null;

  if (s.startsWith('00')) s = '+${s.substring(2)}';
  if (!s.startsWith('+')) {
    // مفتاحُ دولةٍ مكتوبٌ بلا `+`.
    final bare = _known.keys.firstWhere(s.startsWith, orElse: () => '');
    if (bare.isNotEmpty) {
      s = '+$s';
    } else {
      // رقمٌ محلّيّ: يُسقط صفرُه السابقُ ويُنسب إلى اليمن.
      s = '+967${s.startsWith('0') ? s.substring(1) : s}';
    }
  }

  if (!RegExp(r'^\+\d+$').hasMatch(s)) return null;
  final body = s.substring(1);

  for (final entry in _known.entries) {
    if (!body.startsWith(entry.key)) continue;
    final local = body.substring(entry.key.length);
    final rule = entry.value;
    // **والطولُ يُفحص والبدايةُ معه.** رقمٌ يمنيٌّ بتسعِ خاناتٍ يبدأ بـ1
    // ليس جوالاً بل هاتفاً أرضيّاً، ولا يصله واتساب.
    if (local.length != rule.length) return null;
    if (!local.startsWith(rule.starts)) return null;
    return s;
  }

  // مفتاحٌ لا نعرفه: حدٌّ عامٌّ يمنع الناقصَ الظاهرَ ولا يحكم على بلدٍ
  // بعينه. وأقصرُ رقمٍ دوليٍّ معروفٍ ثمانٍ، وأطولُه خمسةَ عشر (E.164).
  return body.length >= 10 && body.length <= 15 ? s : null;
}

/// هل هذا رقمٌ صالحٌ — سؤالٌ للنماذج.
bool isValidPhone(String raw) => normalisePhone(raw) != null;

/// يجمع مفتاحَ الدولة المختار [dial] إلى ما كُتب في الحقل [raw].
///
/// **ولمفتاح «+967» بجانب الحقل ثلاثُ حالاتٍ لا حالةٌ واحدة:**
/// - كتب رقماً محلّيّاً (`771234567` أو `0771234567`): يُسبَق بالمفتاح،
///   ويُسقط صفرُه السابق — وإلّا صار `+9670771…` فرُدّ.
/// - كتب الرقمَ بمفتاحه (`+966…` أو `00966…`): **يُحترم ما كتب** ولا
///   يُلصق مفتاحٌ ثانٍ قبله.
/// - اختار «دولة أخرى» ([dial] فارغ): **يُطلب المفتاحُ مكتوباً** — ولا يُنسب
///   رقمٌ بلا مفتاحٍ إلى اليمن كما يفعل `normalisePhone`: من قال «دولة أخرى»
///   ثمّ كتب رقماً محلّيّاً نسي المفتاح، ونسبتُه إلى اليمن تحفظ له رقماً
///   ليس رقمَه.
String? composePhone(String? dial, String raw) {
  final s = _digits(raw);
  final keyed = s.startsWith('+') || s.startsWith('00');
  if (dial == null) return keyed ? normalisePhone(raw) : null;
  if (keyed) return normalisePhone(raw);
  final local = s.startsWith('0') ? s.substring(1) : s;
  if (local.isEmpty) return null;
  return normalisePhone('+$dial$local');
}

/// الرقمُ كما يُعرض ليُقرأ: `+967 771 234 567`.
///
/// **ويُعرض كاملاً** — شاشةُ التأكيد وُضعت ليرى صاحبُه أنّه كتبه صحيحاً.
/// وما لم يُعرف تقسيمُه يُعرض مطهَّراً كما هو، وما لم يصحّ يُعرض كما كُتب.
String displayPhone(String raw) {
  final s = normalisePhone(raw);
  if (s == null) return raw;
  for (final key in _known.keys) {
    final local = s.substring(1 + key.length);
    if (s.startsWith('+$key') && local.length == 9) {
      return '+$key ${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6)}';
    }
  }
  return s;
}
