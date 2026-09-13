// فتحُ القفل بالبصمة — بابٌ ثانٍ لا بديلٌ عن الرمز.
//
// **وأخطرُ ما يُقاس هنا أنّ الرمزَ لا يسقط.** الحسّاسُ يُخفق، والإصبعُ
// يُبلَّل، والبصماتُ تُمحى بترقية نظام — فلو سقطت لوحةُ الأرقام حين تُشغَّل
// البصمةُ لَبقي صاحبُ الحساب محبوساً عن حجوزاته ومحادثاته. وهو أذىً أكبرُ
// من الذي يمنعه القفل.
//
// **وثانيها أنّ إخفاق البصمة لا يُعدّ محاولةً خاطئة.** عدُّ المحاولات حرزٌ
// من تجريب عشرةِ آلاف رمز، ومن أخفق حسّاسُه خمسَ مرّاتٍ ليس مجرّباً —
// ولو عُدَّت لَأُخرج حسابُ صاحبها وهو صاحبُها.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_lock.dart';
import 'package:aras/src/core/biometrics.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/lock.dart';

/// حسّاسٌ مركَّب — **لا حسّاسَ في `flutter test`**.
class _Fake implements Biometrics {
  _Fake({this.has = true});

  /// أفي «الجهاز» بصمةٌ مسجّلة.
  final bool has;

  /// أتطابق حين تُسأل — تُبدَّل في الاختبار نفسِه.
  bool ok = true;

  /// كم مرّةً سُئلت — **وهو المقيس في «لا تُسأل مرّتين»**.
  int asked = 0;

  @override
  Future<bool> available() async => has;

  @override
  Future<bool> authenticate() async {
    asked++;
    return ok;
  }
}

Widget _wrap(Widget child) => MaterialApp(
  theme: buildTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// قفلٌ مضبوطٌ برمزٍ، وبصمتُه مشغّلةٌ أو مطفأة.
Future<AppLock> _lock({required bool biometric}) async {
  final lock = AppLock();
  await lock.enable('1234');
  if (biometric) await lock.setBiometric(true);
  // القفلُ يُفتح بعد `enable` — ويُقفل هنا لأنّ الشاشةَ لا تُعرض إلّا مقفلة.
  lock.onLeave();
  lock.onReturn();
  return lock;
}

const _button = ValueKey('unlock-biometric');

void main() {
  late _Fake fake;

  setUp(() {
    lockStorageOverride = {};
    fake = _Fake();
    biometricsOverride = fake;
  });

  tearDown(() {
    lockStorageOverride = null;
    biometricsOverride = null;
  });

  group('الخزنةُ والحال', () {
    test('**ولا بصمةَ بلا رمزٍ مضبوط**', () async {
      // بصمةٌ وحدَها قفلٌ لا مخرجَ منه إن أخفق الحسّاس.
      await expectLater(lockSetBiometric(true), throwsA(isA<String>()));
      expect(await lockBiometricIsOn(), isFalse);
    });

    test('وتُشغَّل وتُطفأ وتُقرأ بعد الإقلاع', () async {
      final lock = await _lock(biometric: true);
      expect(lock.biometricEnabled, isTrue);

      final again = AppLock();
      await again.boot();
      expect(again.biometricEnabled, isTrue);
    });

    test('**وإطفاءُ القفل يُسقط البصمةَ معه**', () async {
      // ولولاه لَعاد من فعّل القفلَ بعد شهرٍ فوجد بصمةً لم يطلبها اليوم.
      final lock = await _lock(biometric: true);
      await lock.disable();
      expect(lock.biometricEnabled, isFalse);
      expect(await lockBiometricIsOn(), isFalse);

      await lock.enable('1234');
      expect(lock.biometricEnabled, isFalse);
    });

    test('ولا تُفتح بالبصمة وهي مطفأة', () async {
      final lock = await _lock(biometric: false);
      expect(await lock.unlockWithBiometrics(), isFalse);
      expect(lock.locked, isTrue);
      // ولا يُسأل الحسّاسُ أصلاً — ولا يُقاطَع صاحبُه بحوارٍ لم يطلبه.
      expect(fake.asked, 0);
    });
  });

  group('الشاشة', () {
    testWidgets('**ولوحةُ الأرقام باقيةٌ مع البصمة**', (tester) async {
      final lock = await _lock(biometric: true);
      fake.ok = false; // لا تُفتح تلقائيّاً فتختفي الشاشة.
      await tester.pumpWidget(_wrap(LockScreen(lock: lock, onSignOut: () async {})));
      await _settle(tester);

      expect(find.byKey(_button), findsOneWidget);
      // **وهذا هو الحرزُ الذي لا يُفرَّط فيه:** الرمزُ طريقٌ قائمٌ دائماً.
      expect(find.byKey(const ValueKey('pin-dots')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.byKey(const ValueKey('forgot-pin')), findsOneWidget);
    });

    testWidgets('ولا زرَّ بصمةٍ لمن لم يشغّلها', (tester) async {
      final lock = await _lock(biometric: false);
      await tester.pumpWidget(_wrap(LockScreen(lock: lock, onSignOut: () async {})));
      await _settle(tester);

      expect(find.byKey(_button), findsNothing);
      expect(fake.asked, 0);
    });

    testWidgets('**ولا زرَّ لمن مَحا بصماتِه من جهازه**', (tester) async {
      // شغّلها ثمّ حذف بصماتِه من إعدادات النظام — فالتفضيلُ قائمٌ
      // والحسّاسُ لا يعرف أحداً. وزرٌّ يُضغط فلا يقع شيءٌ أسوأُ من غيابه.
      final lock = await _lock(biometric: true);
      biometricsOverride = _Fake(has: false);
      await tester.pumpWidget(_wrap(LockScreen(lock: lock, onSignOut: () async {})));
      await _settle(tester);

      expect(find.byKey(_button), findsNothing);
      expect(find.byKey(const ValueKey('pin-dots')), findsOneWidget);
    });

    testWidgets('**وتُسأل البصمةُ تلقائيّاً مرّةً واحدةً لا مرّتين**',
        (tester) async {
      final lock = await _lock(biometric: true);
      fake.ok = false;
      await tester.pumpWidget(_wrap(LockScreen(lock: lock, onSignOut: () async {})));
      await _settle(tester);

      // ولو سُئلت في كلّ بناءٍ لَدار الحوارُ على نفسه فلم يُكتب رمزٌ أبداً.
      expect(fake.asked, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(fake.asked, 1);
    });

    testWidgets('وبصمةٌ طابقت تفتح القفل', (tester) async {
      final lock = await _lock(biometric: true);
      expect(lock.locked, isTrue);

      await tester.pumpWidget(_wrap(LockScreen(lock: lock, onSignOut: () async {})));
      await _settle(tester);

      expect(lock.locked, isFalse);
    });

    testWidgets('**وإخفاقُها لا يُعدّ محاولةً خاطئة**', (tester) async {
      final lock = await _lock(biometric: true);
      fake.ok = false;

      await tester.pumpWidget(_wrap(LockScreen(lock: lock, onSignOut: () async {})));
      await _settle(tester);

      // خمسُ محاولاتٍ خاطئةٍ تُخرج الحساب — ومن أخفق حسّاسُه ليس مجرّباً.
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(_button));
        await _settle(tester);
      }
      expect(lock.locked, isTrue);
      expect(lock.wrongAttempts, 0);
      expect(lock.attemptsLeft, lockMaxAttempts);
      expect(lock.exhausted, isFalse);
    });

    testWidgets('**ولا رسالةَ حمراءَ لمن ألغى الحوار**', (tester) async {
      // ألغى ليكتب رمزَه، ولم يخطئ شيئاً.
      final lock = await _lock(biometric: true);
      fake.ok = false;

      await tester.pumpWidget(_wrap(LockScreen(lock: lock, onSignOut: () async {})));
      await _settle(tester);

      expect(find.textContaining('خاطئ'), findsNothing);
      expect(find.textContaining('بقيت'), findsNothing);
    });

    testWidgets('والرمزُ يفتح القفلَ والبصمةُ مشغّلة', (tester) async {
      final lock = await _lock(biometric: true);
      fake.ok = false;

      await tester.pumpWidget(_wrap(LockScreen(lock: lock, onSignOut: () async {})));
      await _settle(tester);

      for (final d in ['1', '2', '3', '4']) {
        await tester.tap(find.text(d));
        await tester.pump();
      }
      await _settle(tester);
      expect(lock.locked, isFalse);
    });
  });
}
