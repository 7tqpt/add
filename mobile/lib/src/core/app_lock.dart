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

/// بعد كم من الغياب يُطلب الرمز.
enum LockAfter { immediately, oneMinute, fiveMinutes, fifteenMinutes, oneHour }

Duration lockDelay(LockAfter value) => switch (value) {
  LockAfter.immediately => Duration.zero,
  LockAfter.oneMinute => const Duration(minutes: 1),
  LockAfter.fiveMinutes => const Duration(minutes: 5),
  LockAfter.fifteenMinutes => const Duration(minutes: 15),
  LockAfter.oneHour => const Duration(hours: 1),
};

String lockAfterName(LockAfter value) => switch (value) {
  LockAfter.immediately => tr('فوراً'),
  LockAfter.oneMinute => tr('بعد دقيقة'),
  LockAfter.fiveMinutes => tr('بعد خمس دقائق'),
  LockAfter.fifteenMinutes => tr('بعد ربع ساعة'),
  LockAfter.oneHour => tr('بعد ساعة'),
};

/// عددُ المحاولات الخاطئة قبل إخراج الحساب.
///
/// **وخمسٌ لا ثلاث:** الرمزُ يُدخَل بإبهامٍ على شاشةٍ صغيرة، والخطأُ في
/// الإدخال وارد. وثلاثٌ تُخرج صاحبَ الحساب لأنّه أخطأ الضغط.
const lockMaxAttempts = 5;

const _keyHash = 'lock_pin_hash';
const _keySalt = 'lock_pin_salt';
const _keyAfter = 'lock_after';
const _keyLeftAt = 'lock_left_at';

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
  await _write(_keyLeftAt, null);
}

/// أيطابق هذا الرمزُ المضبوط؟
Future<bool> lockVerify(String pin) async {
  final hash = await _read(_keyHash);
  final salt = await _read(_keySalt);
  if (hash == null || salt == null) return false;
  return _digest(pin, salt) == hash;
}

Future<LockAfter> lockAfter() async {
  final saved = await _read(_keyAfter);
  return LockAfter.values.firstWhere(
    (v) => v.name == saved,
    orElse: () => LockAfter.fifteenMinutes,
  );
}

Future<void> lockSetAfter(LockAfter value) => _write(_keyAfter, value.name);

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
  LockAfter _after = LockAfter.fifteenMinutes;
  DateTime? _leftAt;
  int _wrong = 0;

  bool get enabled => _enabled;
  bool get locked => _enabled && _locked;
  LockAfter get after => _after;
  int get wrongAttempts => _wrong;
  int get attemptsLeft => lockMaxAttempts - _wrong;

  /// يُقرأ عند الإقلاع.
  ///
  /// **ولحظةُ المغادرة تُقرأ من الخزنة لا من الذاكرة.** أندرويد يقتل ما في
  /// الخلفيّة متى ضاقت الذاكرة — ومن اختار «بعد ساعة» ثمّ خرج دقيقتين فقُتل
  /// تطبيقُه، لو حُسب القتلُ إقلاعاً جديداً لَطُولب برمزه وهو لم يمضِ عليه
  /// إلّا دقيقتان. فتُحفظ اللحظةُ عند المغادرة وتُقارَن عند العودة، ولا فرقَ
  /// بين عودةٍ من الخلفيّة وعودةٍ بعد قتل.
  ///
  /// **وبلا لحظةٍ محفوظةٍ يُقفل.** أوّلُ إقلاعٍ بعد التفعيل، وخزنةٌ مُسحت،
  /// وجهازٌ أُعيد تشغيله — كلُّها مجهولةٌ المدّة، والمجهولُ يُقفل.
  Future<void> boot() async {
    _enabled = await lockIsSet();
    _after = await lockAfter();
    if (!_enabled) {
      _locked = false;
      notifyListeners();
      return;
    }
    final saved = DateTime.tryParse(await _read(_keyLeftAt) ?? '');
    _locked =
        saved == null || DateTime.now().difference(saved) >= lockDelay(_after);
    notifyListeners();
  }

  /// يُنادى حين يغادر التطبيقُ المقدّمة.
  void onLeave() {
    if (!_enabled) return;
    final now = DateTime.now();
    _leftAt = now;
    // بلا `await`: `didChangeAppLifecycleState` لا ينتظر، والنظامُ قد يجمّد
    // التطبيق بعد لحظات — فتُطلق الكتابةُ ولا يُوقَف عليها شيء.
    _write(_keyLeftAt, now.toIso8601String());
  }

  /// يُنادى عند العودة — فيُقفل إن طال الغياب.
  void onReturn() {
    if (!_enabled || _locked) return;
    final left = _leftAt;
    if (left == null) return;
    if (DateTime.now().difference(left) >= lockDelay(_after)) {
      _locked = true;
      notifyListeners();
    }
  }

  /// يفتح بالرمز، أو يعدّ محاولةً خاطئة.
  ///
  /// ويعيد `true` إن فُتح. ومن بلغ الحدَّ يُخرَج حسابُه — والمنادي هو من
  /// يُخرجه، فالخروجُ شأنُ الجلسة لا شأنُ القفل.
  Future<bool> unlock(String pin) async {
    if (await lockVerify(pin)) {
      _locked = false;
      _wrong = 0;
      _leftAt = null;
      // **وتُجدَّد اللحظةُ عند الفتح.** ولولا ذلك لَبقيت لحظةُ الغياب
      // القديمةَ محفوظةً، فمن فتح قفلَه ثمّ قُتل تطبيقُه بعد ثانية وجد
      // الرمزَ مرّةً أخرى وهو لم يغب.
      await _write(_keyLeftAt, DateTime.now().toIso8601String());
      notifyListeners();
      return true;
    }
    _wrong++;
    notifyListeners();
    return false;
  }

  bool get exhausted => _wrong >= lockMaxAttempts;

  Future<void> enable(String pin, LockAfter after) async {
    await lockSetPin(pin);
    await lockSetAfter(after);
    // ولحظةُ التفعيل استعمالٌ — فمن فعّله ثمّ قُتل تطبيقُه لا يُقفل عليه
    // فوراً وهو لم يغادر.
    await _write(_keyLeftAt, DateTime.now().toIso8601String());
    _enabled = true;
    _after = after;
    _locked = false;
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

  Future<void> changeAfter(LockAfter value) async {
    await lockSetAfter(value);
    _after = value;
    notifyListeners();
  }

  /// يُنادى بعد الخروج: القفلُ يُزال مع الحساب.
  ///
  /// **ولولا هذا لَبقي رمزُ من خرج قائماً**، فيدخل صاحبٌ آخرُ بحسابه على
  /// الجهاز نفسه فيجد رمزاً لا يعرفه ولا سبيلَ له إليه.
  Future<void> forget() => disable();
}
