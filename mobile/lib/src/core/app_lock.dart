// قفلُ التطبيق: رمزٌ رباعيٌّ يُطلب بعد غيابٍ طويل.
//
// ── ما هو، وما ليس هو ───────────────────────────────────────────────────────
//
// **وهو قفلُ خصوصيّةٍ لا حصنُ أمان، ويُقال ذلك صراحةً.** أربعةُ أرقامٍ عشرةُ
// آلاف احتمالٍ لا غير. فمن أخذ الجهازَ ومعه وقتٌ يجرّبها كلَّها. وما يمنعه
// هنا شيئان: عدُّ المحاولات، وإخراجُ الحساب بعد خمسٍ خاطئة — فيصير الطريقُ
// الوحيدُ بريداً وكلمةَ مرور.
//
// وما يحميه فعلاً: أن يفتح أخوك جوالك فيرى حجوزاتك ومحادثاتك ومبالغك.
//
// ── أربعةُ قراراتٍ تستحقّ أن تُقرأ ──────────────────────────────────────────
//
// **١) الرمزُ لا يُخزَّن، بل تُخزَّن بصمتُه.** SHA-256 على الرمز مع مِلحٍ
// عشوائيٍّ لكلّ جهاز. فمن قرأ الخزنة لم يجد «1234» بل بصمةً لا تُعكس.
//
// **٢) وفي خزنة النظام لا في ملفٍّ عاديّ** — Keychain في آيفون وKeystore في
// أندرويد. و`shared_preferences` تكفي للتفضيلات ولا تصلح لسرّ.
//
// **٣) ولا بدّ من مخرجٍ لمن نسي.** ولولاه لَحُبس صاحبُ الحساب عن حجوزاته
// ومحادثاته إلى الأبد، وهو أذىً أكبرُ من الذي يمنعه القفل. والمخرجُ خروجٌ
// ودخولٌ بالبريد وكلمة المرور — يعرفهما صاحبُ الحساب وحده.
//
// **٤) والقفلُ اختياريّ.** من لم يشغّله لا يراه أبداً — وقفلٌ يُفرض على من
// لا يريده عائقٌ يوميٌّ لا حماية.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'i18n.dart';

// **ولا مهلةَ تُختار بعد اليوم — يُقفل فورَ المغادرة.**
//
// كانت خمسةُ خيارات: فوراً، وبعد دقيقة، وخمسٍ، وربعِ ساعة، وساعة. وحُذفت،
// وحُذف معها حسابُ لحظةِ المغادرة وحفظُها في الخزنة.
//
// **وعلّةُ الحذف أنّ الخيار كان يُضعف القفلَ بيد صاحبه وهو لا يدري.** من
// وضع رمزاً إنّما وضعه ليمنع من يمسك جوالَه أن يقرأ حجوزاته؛ و«بعد ربع
// ساعة» — وكانت هي الافتراضيّة — تعني أنّ من أخذ الجوالَ من يده يفتح كلَّ
// شيءٍ ما لم تمضِ خمسَ عشرةَ دقيقة. وهي الحالُ الغالبة: الجوالُ يُؤخذ
// ويُنظَر فيه ويُعاد في دقيقة.
//
// وخمسةُ أزرارٍ تسأل صاحبَها سؤالاً أمنيّاً لا يملك جوابَه — والجوابُ
// الصحيحُ واحدٌ منها فقط.
//
// **وثمنُه معلومٌ ومقبول:** من فتح ورقةَ المشاركة أو معرضَ الصور ثمّ عاد
// يُطالَب برمزه، لأنّ التطبيق غادر المقدّمةَ فعلاً. وهذا ما تفعله تطبيقاتُ
// البنوك، وهو ثمنُ القفل لا عطبٌ فيه.

/// عددُ المحاولات الخاطئة قبل إخراج الحساب.
///
/// **وخمسٌ لا ثلاث:** الرمزُ يُدخَل بإبهامٍ على شاشةٍ صغيرة، والخطأُ في
/// الإدخال وارد. وثلاثٌ تُخرج صاحبَ الحساب لأنّه أخطأ الضغط.
const lockMaxAttempts = 5;

const _keyHash = 'lock_pin_hash';
const _keySalt = 'lock_pin_salt';
// **ويُمسح مفتاحا العهد القديم عند الإزالة.** «lock_after» و«lock_left_at»
// لم يعودا يُقرآن، لكنّهما باقيان في خزائن الأجهزة التي حدّثت. ومفتاحٌ
// مهجورٌ في الخزنة لا يضرّ اليوم، لكنّه يضرّ يومَ يُكتب مفتاحٌ باسمٍ يشبهه.
const _keyLegacyAfter = 'lock_after';
const _keyLegacyLeftAt = 'lock_left_at';

/// بديلٌ يُركَّب في الاختبارات — لا خزنةَ نظامٍ في `flutter test`.
///
/// **ولولاه لَما قِيس شيءٌ من هذا الملفّ**: خزنةُ النظام شيفرةٌ أصليّة لا
/// وجودَ لها في بيئة الاختبار، فكلُّ نداءٍ يرمي.
Map<String, String>? lockStorageOverride;

Future<String?> _read(String key) async {
  final fake = lockStorageOverride;
  if (fake != null) return fake[key];
  try {
    return await const FlutterSecureStorage().read(key: key);
  } catch (_) {
    return null;
  }
}

Future<void> _write(String key, String? value) async {
  final fake = lockStorageOverride;
  if (fake != null) {
    if (value == null) {
      fake.remove(key);
    } else {
      fake[key] = value;
    }
    return;
  }
  try {
    if (value == null) {
      await const FlutterSecureStorage().delete(key: key);
    } else {
      await const FlutterSecureStorage().write(key: key, value: value);
    }
  } catch (_) {
    // خزنةٌ لا تُكتب: القفلُ لا يُفعَّل، والتطبيق يعمل. ولا يُسقَط شيء.
  }
}

String _digest(String pin, String salt) =>
    sha256.convert(utf8.encode('$salt:$pin')).toString();

String _newSalt() {
  final random = Random.secure();
  return base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
}

/// أرمزٌ مضبوطٌ على هذا الجهاز؟
Future<bool> lockIsSet() async => (await _read(_keyHash)) != null;

/// يضبط الرمز — أربعةُ أرقامٍ لا غير.
///
/// **ويُردّ ما ليس أربعةَ أرقام** هنا لا في الشاشة وحدها: الشاشةُ تُبدَّل
/// وهذا يبقى.
Future<void> lockSetPin(String pin) async {
  if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
    throw tr('الرمز أربعة أرقام.');
  }
  final salt = _newSalt();
  await _write(_keySalt, salt);
  await _write(_keyHash, _digest(pin, salt));
}

/// يزيل القفل.
Future<void> lockClear() async {
  await _write(_keyHash, null);
  await _write(_keySalt, null);
  await _write(_keyLegacyAfter, null);
  await _write(_keyLegacyLeftAt, null);
}

/// أيطابق هذا الرمزُ المضبوط؟
Future<bool> lockVerify(String pin) async {
  final hash = await _read(_keyHash);
  final salt = await _read(_keySalt);
  if (hash == null || salt == null) return false;
  return _digest(pin, salt) == hash;
}

/// النسخةُ الواحدة — كما `appLocale` في `i18n.dart`.
///
/// **ونسخةٌ واحدةٌ لا تمريرٌ عبر أربع شاشات.** القفلُ حالُ التطبيق كلِّه، لا
/// حالُ شاشة. وتمريرُه من الجذر إلى الإعدادات يمرّ بالقشرة وبطاقة الحساب
/// وليس لهما به شأن.
final appLock = AppLock();

/// حارسُ القفل: يعرف متى غاب صاحبُه ومتى يُطلب الرمز.
///
/// **والزمنُ يُقاس عند المغادرة لا عند العودة.** التطبيق قد يُقتل في الخلفيّة
/// فلا يعمل مؤقّتٌ فيه — والذي يبقى هو **لحظةُ آخر استعمال**، تُقارَن بالساعة
/// عند العودة.
class AppLock extends ChangeNotifier {
  bool _enabled = false;
  bool _locked = false;

  /// أغادر التطبيقُ المقدّمةَ منذ آخر فتح؟
  ///
  /// **وعلامةٌ لا لحظةُ زمن.** لم يبقَ ما يُحسب: الغيابُ غيابٌ مهما قصر.
  /// وهي تمنع أن يُقفل التطبيقُ على `resumed` جاءت بلا `paused` قبلها —
  /// وهي تقع في بعض الأجهزة.
  bool _left = false;
  int _wrong = 0;

  bool get enabled => _enabled;
  bool get locked => _enabled && _locked;
  int get wrongAttempts => _wrong;
  int get attemptsLeft => lockMaxAttempts - _wrong;

  /// يُقرأ عند الإقلاع — **وكلُّ إقلاعٍ مقفل**.
  ///
  /// وهو أصدقُ ما يمكن قولُه: التطبيقُ كان مغلقاً، ولا يُعرف كم مضى ولا في
  /// يد من كان الجوال.
  Future<void> boot() async {
    _enabled = await lockIsSet();
    _locked = _enabled;
    _left = false;
    notifyListeners();
  }

  /// يُنادى حين يغادر التطبيقُ المقدّمة.
  ///
  /// ولا يُقفل هنا: القفلُ عند العودة، وإلّا لَرأى صاحبُه شاشةَ الرمز تُرسم
  /// خلفه وهو يغادر.
  void onLeave() {
    if (!_enabled) return;
    _left = true;
  }

  /// يُنادى عند العودة — فيُقفل إن كان غادر.
  void onReturn() {
    if (!_enabled || _locked || !_left) return;
    _locked = true;
    _left = false;
    notifyListeners();
  }

  /// يفتح بالرمز، أو يعدّ محاولةً خاطئة.
  ///
  /// ويعيد `true` إن فُتح. ومن بلغ الحدَّ يُخرَج حسابُه — والمنادي هو من
  /// يُخرجه، فالخروجُ شأنُ الجلسة لا شأنُ القفل.
  Future<bool> unlock(String pin) async {
    if (await lockVerify(pin)) {
      _locked = false;
      _wrong = 0;
      _left = false;
      notifyListeners();
      return true;
    }
    _wrong++;
    notifyListeners();
    return false;
  }

  bool get exhausted => _wrong >= lockMaxAttempts;

  /// يفعّل القفل بالرمز — **ولا يُقفل عليه في اللحظة نفسِها**.
  ///
  /// من ضبط رمزَه للتوّ لم يغادر بعد، وشاشةُ رمزٍ تُلقى في وجهه فورَ الضبط
  /// تُقرأ عطباً لا حمايةً.
  Future<void> enable(String pin) async {
    await lockSetPin(pin);
    _enabled = true;
    _locked = false;
    _left = false;
    _wrong = 0;
    notifyListeners();
  }

  Future<void> disable() async {
    await lockClear();
    _enabled = false;
    _locked = false;
    _wrong = 0;
    notifyListeners();
  }

  /// يُنادى بعد الخروج: القفلُ يُزال مع الحساب.
  ///
  /// **ولولا هذا لَبقي رمزُ من خرج قائماً**، فيدخل صاحبٌ آخرُ بحسابه على
  /// الجهاز نفسه فيجد رمزاً لا يعرفه ولا سبيلَ له إليه.
  Future<void> forget() => disable();
}
