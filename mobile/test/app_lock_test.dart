// قفلُ التطبيق: رمزٌ رباعيٌّ بعد غيابٍ طويل.
//
// **وأخطرُ ما يُقاس هنا ليس أنّ القفل يعمل، بل أنّ له مخرجاً.** قفلٌ لا مخرجَ
// منه يحبس صاحبَ الحساب عن حجوزاته ومحادثاته إلى الأبد — وهو أذىً أكبرُ من
// الذي يمنعه القفل.
//
// ويُقاس معه أنّ الرمز **لا يُخزَّن نصّاً**، وأنّ المحاولات محدودة: أربعةُ
// أرقامٍ عشرةُ آلاف احتمال، تُجرَّب كلُّها في جلسةٍ لولا الحدّ.
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_lock.dart';

void main() {
  late Map<String, String> storage;

  setUp(() {
    storage = {};
    lockStorageOverride = storage;
  });
  tearDown(() => lockStorageOverride = null);

  // ==========================================================================
  //  **الرمزُ لا يُخزَّن نصّاً**
  // ==========================================================================

  group('تخزينُ الرمز', () {
    test('**لا يظهر الرمزُ في المخزَن**', () async {
      // ومن قرأ الخزنة يجب ألّا يجد «1234» بل بصمةً لا تُعكس.
      await lockSetPin('1234');
      expect(storage.values.join(), isNot(contains('1234')));
    });

    test('وبصمتان لرمزٍ واحدٍ تختلفان — لكلّ جهازٍ مِلحُه', () async {
      // **ولولا المِلح** لكانت بصمةُ «1234» واحدةً في كلّ جهاز، فمن عرف
      // بصمةَ رمزٍ شائعٍ عرفه في كلّ جهاز.
      await lockSetPin('1234');
      final first = storage['lock_pin_hash'];
      storage.clear();
      await lockSetPin('1234');
      expect(storage['lock_pin_hash'], isNot(first));
    });

    test('والرمزُ الصحيح يُقبل', () async {
      await lockSetPin('4821');
      expect(await lockVerify('4821'), isTrue);
    });

    test('والخاطئُ يُردّ', () async {
      await lockSetPin('4821');
      expect(await lockVerify('4822'), isFalse);
    });

    test('**وما ليس أربعةَ أرقامٍ يُردّ في القلب لا في الشاشة**', () async {
      // الشاشةُ تُبدَّل وهذا يبقى.
      for (final bad in ['123', '12345', 'abcd', '', '12a4']) {
        expect(() => lockSetPin(bad), throwsA(isA<String>()), reason: bad);
      }
    });

    test('وبلا رمزٍ مضبوطٍ لا شيءَ يُقبل', () async {
      expect(await lockVerify('1234'), isFalse);
    });
  });

  // ==========================================================================
  //  الغيابُ والقفل
  // ==========================================================================

  group('متى يُقفل', () {
    test('**ويبدأ مقفولاً عند الإقلاع إن كان مضبوطاً**', () async {
      // فمن أغلق جواله ليلاً وفتحه صباحاً يجد الرمز، لا شاشتَه مفتوحة.
      await lockSetPin('1111');
      final lock = AppLock();
      await lock.boot();
      expect(lock.enabled, isTrue);
      expect(lock.locked, isTrue);
    });

    test('ومن لا رمزَ له لا يرى قفلاً أبداً', () async {
      final lock = AppLock();
      await lock.boot();
      expect(lock.enabled, isFalse);
      expect(lock.locked, isFalse);
    });

    test('**وغيابٌ قصيرٌ لا يقفل**', () async {
      // ومن ردّ على مكالمةٍ ثمّ عاد بعد ثانيتين لا يُطالَب برمز — وقفلٌ
      // يُطلب في كلّ تبديلِ تطبيقٍ يُطفئه صاحبُه في يومه الأوّل.
      await lockSetPin('1111');
      final lock = AppLock();
      await lock.boot();
      await lock.unlock('1111');
      await lock.changeAfter(LockAfter.fifteenMinutes);

      lock.onLeave();
      lock.onReturn();
      expect(lock.locked, isFalse);
    });

    test('**و«فوراً» تقفل عند أوّل مغادرة**', () async {
      await lockSetPin('1111');
      final lock = AppLock();
      await lock.boot();
      await lock.unlock('1111');
      await lock.changeAfter(LockAfter.immediately);

      lock.onLeave();
      lock.onReturn();
      expect(lock.locked, isTrue);
    });

    test('وعودةٌ بلا مغادرةٍ لا تقفل', () async {
      await lockSetPin('1111');
      final lock = AppLock();
      await lock.boot();
      await lock.unlock('1111');
      lock.onReturn();
      expect(lock.locked, isFalse);
    });

    // ========================================================================
    //  **الإقلاعُ بعد قتلِ النظام**
    // ========================================================================
    //
    // أندرويد يقتل ما في الخلفيّة متى ضاقت الذاكرة. ولو حُسب القتلُ إقلاعاً
    // جديداً لَصارت كلُّ المدد «فوراً» عملياً — واختيارُ صاحبِ الجهاز لا
    // معنى له.

    test('**وقتلُ النظامِ بعد غيابٍ قصيرٍ لا يقفل**', () async {
      await lockSetPin('1111');
      await lockSetAfter(LockAfter.oneHour);
      // خرج قبل دقيقتين ثمّ قُتل تطبيقُه.
      storage['lock_left_at'] =
          DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String();

      final lock = AppLock();
      await lock.boot();
      expect(lock.locked, isFalse,
          reason: 'طُولب برمزه ولم يمضِ عليه إلّا دقيقتان');
    });

    test('وقتلُ النظامِ بعد غيابٍ طويلٍ يقفل', () async {
      await lockSetPin('1111');
      await lockSetAfter(LockAfter.fifteenMinutes);
      storage['lock_left_at'] =
          DateTime.now().subtract(const Duration(hours: 3)).toIso8601String();

      final lock = AppLock();
      await lock.boot();
      expect(lock.locked, isTrue);
    });

    test('و«فوراً» تقفل عند الإقلاع مهما قصُر الغياب', () async {
      await lockSetPin('1111');
      await lockSetAfter(LockAfter.immediately);
      storage['lock_left_at'] = DateTime.now().toIso8601String();

      final lock = AppLock();
      await lock.boot();
      expect(lock.locked, isTrue);
    });

    test('**ولحظةٌ محفوظةٌ فاسدةٌ تُقفل ولا تُسقط**', () async {
      // خزنةٌ عبثَ بها أحدٌ أو تلفت — والمجهولُ يُقفل، ولا يرمي الإقلاع.
      await lockSetPin('1111');
      storage['lock_left_at'] = 'ليس تاريخاً';

      final lock = AppLock();
      await lock.boot();
      expect(lock.locked, isTrue);
    });

    test('**والفتحُ يُجدّد اللحظة**', () async {
      // ولولاه لَبقيت لحظةُ الغياب القديمة، فمن فتح قفلَه ثمّ قُتل تطبيقُه
      // بعد ثانيةٍ وجد الرمزَ وهو لم يغب.
      await lockSetPin('1111');
      await lockSetAfter(LockAfter.oneHour);
      storage['lock_left_at'] =
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String();

      final first = AppLock();
      await first.boot();
      expect(first.locked, isTrue);
      await first.unlock('1111');

      final second = AppLock();
      await second.boot();
      expect(second.locked, isFalse, reason: 'بقيت اللحظةُ القديمة بعد الفتح');
    });

    test('والمغادرةُ تكتب اللحظةَ في الخزنة', () async {
      await lockSetPin('1111');
      final lock = AppLock();
      await lock.boot();
      await lock.unlock('1111');
      storage.remove('lock_left_at');

      lock.onLeave();
      await Future<void>.delayed(Duration.zero);
      expect(storage['lock_left_at'], isNotNull);
    });

    test('والمدّةُ تُحفظ وتُقرأ عند الإقلاع', () async {
      await lockSetPin('1111');
      await lockSetAfter(LockAfter.oneHour);
      final lock = AppLock();
      await lock.boot();
      expect(lock.after, LockAfter.oneHour);
    });
  });

  // ==========================================================================
  //  **الحدُّ والمخرج**
  // ==========================================================================

  group('المحاولات', () {
    test('**تنفد بعد خمسٍ خاطئة**', () async {
      // عشرةُ آلاف احتمالٍ تُجرَّب في جلسةٍ واحدة لولا الحدّ.
      await lockSetPin('1111');
      final lock = AppLock();
      await lock.boot();

      for (var i = 0; i < lockMaxAttempts; i++) {
        expect(lock.exhausted, isFalse, reason: 'نفدت مبكّراً عند $i');
        await lock.unlock('0000');
      }
      expect(lock.exhausted, isTrue);
    });

    test('وخمسٌ لا ثلاث — فالخطأُ بالإبهام وارد', () {
      expect(lockMaxAttempts, 5);
    });

    test('والعدّادُ يُصفَّر بفتحٍ صحيح', () async {
      await lockSetPin('1111');
      final lock = AppLock();
      await lock.boot();
      await lock.unlock('0000');
      await lock.unlock('0000');
      expect(lock.wrongAttempts, 2);

      await lock.unlock('1111');
      expect(lock.wrongAttempts, 0);
      expect(lock.locked, isFalse);
    });

    test('**والنسيانُ يُزيل القفل — ولا بدّ من هذا المخرج**', () async {
      // ولولاه لَحُبس صاحبُ الحساب عن حجوزاته إلى الأبد.
      await lockSetPin('1111');
      final lock = AppLock();
      await lock.boot();

      await lock.forget();
      expect(lock.enabled, isFalse);
      expect(lock.locked, isFalse);
      expect(await lockIsSet(), isFalse, reason: 'بقيت البصمةُ في الخزنة');
    });

    test('وإطفاؤه يمحو البصمةَ والمِلح', () async {
      await lockSetPin('1111');
      final lock = AppLock();
      await lock.boot();
      lock.onLeave();
      await Future<void>.delayed(Duration.zero);
      await lock.disable();
      expect(storage.containsKey('lock_pin_hash'), isFalse);
      expect(storage.containsKey('lock_pin_salt'), isFalse);
      expect(storage.containsKey('lock_left_at'), isFalse);
    });
  });

  // ==========================================================================
  //  المدد
  // ==========================================================================

  test('ولكلّ مدّةٍ اسمٌ وزمنٌ يوافقه', () {
    expect(lockDelay(LockAfter.immediately), Duration.zero);
    expect(lockDelay(LockAfter.fifteenMinutes), const Duration(minutes: 15));
    expect(lockDelay(LockAfter.oneHour), const Duration(hours: 1));
    for (final v in LockAfter.values) {
      expect(lockAfterName(v).trim(), isNotEmpty, reason: v.name);
    }
  });
}
