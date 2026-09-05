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

    // ========================================================================
    //  **فورَ المغادرة — لا مهلةَ تُختار**
    //
    //  كانت خمسُ مددٍ تُختار، وحُذفت. وأشيعُها «بعد ربع ساعة» — أي أنّ من
    //  أخذ الجوالَ من يد صاحبه يقرأ كلَّ شيءٍ ما لم تمضِ خمسَ عشرةَ دقيقة،
    //  وهي الحالُ الغالبة: الجوالُ يُؤخذ ويُنظَر فيه ويُعاد في دقيقة.
    // ========================================================================

    test('**والمغادرةُ تقفل مهما قصُرت**', () async {
      await lockSetPin('1111');
      final lock = AppLock();
      await lock.boot();
      await lock.unlock('1111');

      lock.onLeave();
      lock.onReturn();
      expect(lock.locked, isTrue, reason: 'غادر التطبيقُ ولم يُقفل');
    });

    test('**وعودةٌ بلا مغادرةٍ لا تقفل**', () async {
      // بعضُ الأجهزة تُرسل `resumed` بلا `paused` قبلها — وقفلٌ عندها
      // يُلقي شاشةَ الرمز في وجه من لم يغادر.
      await lockSetPin('1111');
      final lock = AppLock();
      await lock.boot();
      await lock.unlock('1111');
      lock.onReturn();
      expect(lock.locked, isFalse);
    });

    test('**ومغادرتان متتاليتان لا تُبقيان علامةً معلّقة**', () async {
      // من غادر وعاد فأدخل رمزَه، ثمّ عاد `resumed` مرّةً أخرى بلا مغادرة،
      // لا يُقفل عليه ثانيةً.
      await lockSetPin('1111');
      final lock = AppLock();
      await lock.boot();
      await lock.unlock('1111');

      lock.onLeave();
      lock.onReturn();
      await lock.unlock('1111');
      lock.onReturn();
      expect(lock.locked, isFalse, reason: 'بقيت علامةُ المغادرة بعد الفتح');
    });

    test('**وكلُّ إقلاعٍ مقفل**', () async {
      // التطبيقُ كان مغلقاً، ولا يُعرف كم مضى ولا في يد من كان الجوال.
      await lockSetPin('1111');
      final lock = AppLock();
      await lock.boot();
      expect(lock.locked, isTrue);
    });

    test('**والتفعيلُ لا يقفل في اللحظة نفسِها**', () async {
      // من ضبط رمزَه للتوّ لم يغادر بعد، وشاشةُ رمزٍ فورَ الضبط تُقرأ عطباً.
      final lock = AppLock();
      await lock.boot();
      await lock.enable('1111');
      expect(lock.enabled, isTrue);
      expect(lock.locked, isFalse);
    });

    test('ولا يبقى مفتاحُ المدّة القديم بعد الإزالة', () async {
      // «lock_after» و«lock_left_at» باقيان في خزائن الأجهزة التي حدّثت.
      await lockSetPin('1111');
      storage['lock_after'] = 'oneHour';
      storage['lock_left_at'] = DateTime.now().toIso8601String();

      await lockClear();
      expect(storage['lock_after'], isNull);
      expect(storage['lock_left_at'], isNull);
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

}
