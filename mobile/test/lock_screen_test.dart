// شاشةُ القفل: اللوحةُ والنقاطُ والمخرج.
//
// **واختبارُ القلب لا يقول شيئاً عن الشاشة.** `app_lock_test.dart` يقيس
// البصمةَ والحدَّ والمدد — ولا يعرف أنّ زرّ «٧» يُدخل سبعةً، ولا أنّ الخروج
// يقع فعلاً بعد خمسٍ خاطئة، ولا أنّ «نسيتُ الرمز» موصولٌ بشيء. وثلاثتُها هي
// ما يراه صاحبُ الجهاز.
//
// وأثقلُها وزناً: **أنّ المخرجَ يعمل**. قفلٌ مخرجُه زرٌّ لا يفعل شيئاً أسوأُ
// من قفلٍ بلا زرّ — لأنّه يَعِد.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_lock.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/lock.dart';

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

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// عددُ النقاط المملوءة — تُعرف بلونها لا بنصّها، فالرمزُ لا يُعرض.
int _filled(WidgetTester tester) {
  final row = tester.widget<Row>(find.byKey(const ValueKey('pin-dots')));
  var n = 0;
  for (final dot in row.children.whereType<Container>()) {
    final box = dot.decoration as BoxDecoration;
    if (box.color == AppColors.accent) n++;
  }
  return n;
}

Future<void> _type(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.byKey(ValueKey('pad-$d')));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  late Map<String, String> storage;
  late AppLock lock;
  var signedOut = 0;

  setUp(() async {
    storage = {};
    lockStorageOverride = storage;
    signedOut = 0;
    await lockSetPin('4821');
    lock = AppLock();
    await lock.boot();
  });
  tearDown(() => lockStorageOverride = null);

  Future<void> open(WidgetTester tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(LockScreen(
      lock: lock,
      onSignOut: () async => signedOut++,
    )));
    await tester.pump();
  }

  // ==========================================================================
  //  اللوحةُ والنقاط
  // ==========================================================================

  test('الأساس: يبدأ مقفولاً', () => expect(lock.locked, isTrue));

  testWidgets('**تُركَّب الشاشةُ بلا استثناء**', (tester) async {
    // درسٌ من `MapPickerScreen`: زرٌّ في `Row` بأدنى عرضٍ لانهائيّ في السمة
    // رمى ثلاثةَ عشرَ استثناءَ تخطيطٍ لم يرها أحد.
    await open(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('pad-7')), findsOneWidget);
  });

  testWidgets('وكلُّ رقمٍ يملأ نقطة', (tester) async {
    await open(tester);
    expect(_filled(tester), 0);
    await tester.tap(find.byKey(const ValueKey('pad-1')));
    await tester.pump();
    expect(_filled(tester), 1);
    await tester.tap(find.byKey(const ValueKey('pad-2')));
    await tester.pump();
    expect(_filled(tester), 2);
  });

  testWidgets('**ولا يظهر الرقمُ المُدخل على الشاشة**', (tester) async {
    // من نظر من فوق كتفك يرى النقاطَ لا الأرقام.
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('pad-7')));
    await tester.pump();
    // «٧» موجودةٌ في اللوحة نفسها — الممنوعُ أن تظهر **مرّتين**.
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('وزرُّ المحو يُرجع نقطة', (tester) async {
    await open(tester);
    await _type(tester, '12');
    await tester.tap(find.byKey(const ValueKey('pad-back')));
    await tester.pump();
    expect(_filled(tester), 1);
  });

  testWidgets('ومحوٌ على فارغٍ لا يرمي', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('pad-back')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(_filled(tester), 0);
  });

  // ==========================================================================
  //  الفتحُ والخطأ
  // ==========================================================================

  testWidgets('**والرمزُ الصحيح يفتح بلا زرّ «تمّ»**', (tester) async {
    await open(tester);
    await _type(tester, '4821');
    expect(lock.locked, isFalse);
  });

  testWidgets('والخاطئُ يُبقيها مقفولةً ويقول كم بقي', (tester) async {
    await open(tester);
    await _type(tester, '0000');
    expect(lock.locked, isTrue);
    expect(find.textContaining('بقيت'), findsOneWidget);
    expect(_filled(tester), 0, reason: 'لم تُفرَّغ النقاطُ بعد الخطأ');
  });

  testWidgets('والعدُّ ينقص مع كلّ خطأ', (tester) async {
    await open(tester);
    // **و«٤» وحدها لا تدلّ على شيء** — في اللوحة زرٌّ اسمه «4». فيُطلب
    // النصُّ كلُّه: «بقيت ٤ محاولات».
    await _type(tester, '0000');
    expect(find.text('رمزٌ خاطئ — بقيت 4 محاولات.'), findsOneWidget);
    await _type(tester, '0000');
    expect(find.text('رمزٌ خاطئ — بقيت 3 محاولات.'), findsOneWidget);
    expect(lock.attemptsLeft, 3);
  });

  // ==========================================================================
  //  **المخرجان**
  // ==========================================================================

  testWidgets('**وبعد خمسٍ خاطئةٍ يُخرَج الحسابُ ويُزال القفل**',
      (tester) async {
    // ولولا هذا لَجُرّبت عشرةُ آلافِ احتمالٍ في جلسةٍ واحدة.
    await open(tester);
    for (var i = 0; i < lockMaxAttempts; i++) {
      expect(signedOut, 0, reason: 'خرج مبكّراً عند المحاولة $i');
      await _type(tester, '0000');
    }
    expect(signedOut, 1);
    expect(await lockIsSet(), isFalse,
        reason: 'خرج الحسابُ وبقيت البصمةُ — فيُقفل على الداخل بعده');
  });

  testWidgets('**و«نسيتُ الرمز» يُخرج فعلاً بعد التأكيد**', (tester) async {
    // زرٌّ يَعِد بمخرجٍ ولا يفتحه أسوأُ من غيابه.
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('forgot-pin')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اخرج وأعد الدخول'));
    await tester.pumpAndSettle();

    expect(signedOut, 1);
    expect(lock.enabled, isFalse);
    expect(await lockIsSet(), isFalse);
  });

  testWidgets('وإلغاءُ التأكيد لا يُخرج شيئاً', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('forgot-pin')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(signedOut, 0);
    expect(lock.enabled, isTrue);
    expect(await lockIsSet(), isTrue);
  });

  // ==========================================================================
  //  ورقةُ الضبط
  // ==========================================================================

  group('askPin', () {
    Future<String?> result = Future.value(null);

    testWidgets('**تُغلق من نفسها عند الرقم الرابع**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(Builder(
        builder: (context) => TextButton(
          onPressed: () => result = askPin(context, title: 'اختر رمزاً'),
          child: const Text('افتح'),
        ),
      )));
      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();

      await _type(tester, '9182');
      expect(await result, '9182');
    });

    testWidgets('والرجوعُ بلا إدخالٍ يعيد فارغاً', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(Builder(
        builder: (context) => TextButton(
          onPressed: () => result = askPin(context, title: 'اختر رمزاً'),
          child: const Text('افتح'),
        ),
      )));
      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(await result, isNull);
    });
  });
}
