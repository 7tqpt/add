// **لا يُفتح التطبيقُ قبل ضبط قفلٍ — للعميل ومقدّم الخدمة جميعاً.**
//
// ── ما يحرسه هذا الملفّ ──────────────────────────────────────────────────────
//
// **١) البابُ يقف مكانَ التطبيق لمن لم يضبط قفلاً.** ولا يكفي أن تُرسم
//    الشاشة: المقصودُ ألّا يصل إلى حجوزاته ومحادثاته قبلها.
//
// **٢) ولا زرَّ «لاحقاً».** بابٌ يُتخطّى ليس باباً — وهو الفرقُ بين الإجبار
//    والتشجيع.
//
// **٣) ومن ضبط الرمزَ دخل فوراً.** البابُ يختفي بنفسه، ولا يُطالَب بالرمز
//    الذي ضبطه للتوّ.
//
// **٤) ولا يُطفأ من الإعدادات.** ولولا هذا لَكان الفرضُ زينةً: يُضبط عند
//    الدخول ويُطفأ بعد دقيقة.
//
// **٥) والمخرجُ خروجٌ لا حبس.** من لم يُرد قفلاً يخرج من حسابه — ولا يُترك
//    في شاشةٍ بلا باب.
//
// ── وقرارٌ نُقض عمداً ───────────────────────────────────────────────────────
//
// في رأس `app_lock.dart`: «القفلُ اختياريّ… وقفلٌ يُفرض على من لا يريده
// عائقٌ يوميٌّ لا حماية». وعُرضت الصورةُ على صاحب المنصّة بثمنها فاختار
// الفرضَ فورَ الدخول بلا إطفاء. وهذه الحزمةُ تحرس اختيارَه.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_lock.dart';
import 'package:aras/src/core/biometrics.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/screens/account_extras.dart';
import 'package:aras/src/screens/lock.dart';
import 'package:aras/src/screens/root.dart';

class _Sensor implements Biometrics {
  const _Sensor({this.has = true});
  final bool has;

  @override
  Future<bool> available() async => has;

  @override
  Future<bool> authenticate() async => true;
}

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'ayman@sdd.company'
  ..appUserId = 'a1'
  ..loading = false;

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
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// يكتب رمزاً في لوحة الأرقام المعروضة.
Future<void> _type(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.widgetWithText(InkWell, d).first);
    await tester.pump(const Duration(milliseconds: 60));
  }
  await _settle(tester);
}

void main() {
  setUp(() {
    // **ولا خزنةَ نظامٍ في `flutter test`** — فيُركَّب بديلٌ في الذاكرة.
    lockStorageOverride = {};
    biometricsOverride = const _Sensor();
  });
  tearDown(() {
    lockStorageOverride = null;
    biometricsOverride = null;
  });

  group('**البابُ يقف مكانَ التطبيق**', () {
    testWidgets('يُعرض لمن لم يضبط قفلاً', (tester) async {
      _phone(tester);
      final lock = AppLock();
      await lock.boot();

      await tester.pumpWidget(_wrap(
        LockGateScreen(lock: lock, onSignOut: () async {}),
      ));
      await _settle(tester);

      expect(find.text('اقفل تطبيقك قبل أن تبدأ'), findsOneWidget);
      expect(find.byKey(const ValueKey('gate-set-pin')), findsOneWidget);
    });

    testWidgets('**ولا زرَّ «لاحقاً» فيه**', (tester) async {
      // **وهذا هو الفرقُ بين الإجبار والتشجيع.** بابٌ يُتخطّى ليس باباً.
      _phone(tester);
      final lock = AppLock();
      await lock.boot();

      await tester.pumpWidget(_wrap(
        LockGateScreen(lock: lock, onSignOut: () async {}),
      ));
      await _settle(tester);

      expect(find.text('لاحقاً'), findsNothing);
      expect(find.text('تخطّي'), findsNothing);
      expect(find.text('ليس الآن'), findsNothing);
    });

    testWidgets('**والمخرجُ خروجٌ لا حبس**', (tester) async {
      // من لم يُرد قفلاً لا يُترك في شاشةٍ بلا باب.
      _phone(tester);
      final lock = AppLock();
      await lock.boot();
      var out = false;

      await tester.pumpWidget(_wrap(
        LockGateScreen(lock: lock, onSignOut: () async => out = true),
      ));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('gate-sign-out')));
      await _settle(tester);

      expect(out, isTrue, reason: 'ضُغط «خروج» ولم يخرج شيء');
    });

    testWidgets('**ولا يُوعَد ببصمةٍ ليست في الجهاز**', (tester) async {
      // من قرأ «وبصمتُك تفتحه» ولا حسّاسَ عنده ينتظر شيئاً لا يأتي.
      _phone(tester);
      biometricsOverride = const _Sensor(has: false);
      final lock = AppLock();
      await lock.boot();

      await tester.pumpWidget(_wrap(
        LockGateScreen(lock: lock, onSignOut: () async {}),
      ));
      await _settle(tester);

      expect(find.text('ولا بصمةَ في جهازك'), findsOneWidget);
      expect(find.text('وبصمتُك تفتحه أسرع'), findsNothing);
    });
  });

  group('**والجذرُ يضع البابَ مكانَ التطبيق**', () {
    // **ولا يكفي أن يُبنى البابُ وحدَه في اختبار.** كسرتُ `root.dart` — شُلَّ
    // شرطُ البابِ منه — **فبقيت الحزمةُ خضراء**، لأنّ كلَّ اختباراتي كانت
    // تبني `LockGateScreen` مباشرةً. وحارسٌ لا يمرّ من الطريق الذي يحرسه لا
    // يحرس. فهذه تمرّ من `RootScreen` كما يمرّ المستخدم.
    testWidgets('من دخل بلا قفلٍ يرى البابَ لا التطبيق', (tester) async {
      _phone(tester);
      final lock = AppLock();
      await lock.boot();

      await tester.pumpWidget(_wrap(
        RootScreen(session: _session(), lock: lock),
      ));
      await _settle(tester);

      expect(find.byType(LockGateScreen), findsOneWidget,
          reason: 'دخل التطبيقَ من لا قفلَ له');
      expect(find.text('اقفل تطبيقك قبل أن تبدأ'), findsOneWidget);
    });

    testWidgets('**ومن ضبط قفلَه لا يراه**', (tester) async {
      // **وهذا ما يمنع البابَ من أن يصير جداراً.** لو ظهر لمن ضبط قفله
      // لَمرّ الاختبارُ الأوّلُ على شاشةٍ لا تنزاح أبداً.
      _phone(tester);
      final lock = AppLock();
      await lock.enable('1379');

      await tester.pumpWidget(_wrap(
        RootScreen(session: _session(), lock: lock),
      ));
      await _settle(tester);

      expect(find.byType(LockGateScreen), findsNothing);
    });

    testWidgets('**ويزول البابُ بضبط الرمز بلا إعادة بناء**', (tester) async {
      // **ولا يكفي أن يُضبط الرمزُ في الخزنة:** لولا `notifyListeners` لَبقي
      // البابُ قائماً على قفلٍ مضبوط، ولَظنّ صاحبُه أنّ الضبطَ لم يقع.
      // وقد كسرتُ `notifyListeners` فبقيت الحزمةُ خضراءَ قبل هذه.
      _phone(tester);
      final lock = AppLock();
      await lock.boot();

      await tester.pumpWidget(_wrap(
        RootScreen(session: _session(), lock: lock),
      ));
      await _settle(tester);
      expect(find.byType(LockGateScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('gate-set-pin')));
      await _settle(tester);
      await _type(tester, '1379');
      await _settle(tester);
      await _type(tester, '1379');
      await _settle(tester);

      expect(find.byType(LockGateScreen), findsNothing,
          reason: 'ضُبط الرمزُ والبابُ باقٍ — لم يُخبَر المستمعون');
    });
  });

  group('**وضبطُ الرمز يفتح الطريق**', () {
    testWidgets('يُضبط بخطوتين، فيصير القفلُ مفعّلاً وغيرَ مقفل',
        (tester) async {
      // **ويُقاس ما صار في القفل لا ما رُسم على الشاشة.** بابٌ يختفي وقفلٌ
      // لم يُضبط أسوأُ من بابٍ باقٍ.
      _phone(tester);
      final lock = AppLock();
      await lock.boot();

      await tester.pumpWidget(_wrap(
        LockGateScreen(lock: lock, onSignOut: () async {}),
      ));
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('gate-set-pin')));
      await _settle(tester);
      await _type(tester, '1379');
      await _settle(tester);
      await _type(tester, '1379');
      await _settle(tester);

      expect(lock.enabled, isTrue, reason: 'لم يُضبط الرمز');
      // **ولا يُطالَب بالرمز الذي ضبطه للتوّ.**
      expect(lock.locked, isFalse);
    });

    testWidgets('**ورمزان مختلفان لا يُضبطان**', (tester) async {
      _phone(tester);
      final lock = AppLock();
      await lock.boot();

      await tester.pumpWidget(_wrap(
        LockGateScreen(lock: lock, onSignOut: () async {}),
      ));
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('gate-set-pin')));
      await _settle(tester);
      await _type(tester, '1111');
      await _settle(tester);
      await _type(tester, '2222');
      await _settle(tester);

      expect(lock.enabled, isFalse, reason: 'ضُبط رمزٌ لم يُؤكَّد');
      expect(find.textContaining('لم يتطابقا'), findsOneWidget,
          reason: 'أُغلقت الورقةُ بلا سببٍ يُقرأ');
    });
  });

  group('**ولا يُطفأ بعد ضبطه**', () {
    testWidgets('لا زرَّ إطفاءٍ في شاشة الإعدادات', (tester) async {
      // **وتُبنى الشاشةُ ويُسأل ما فيها.** كتبتُ هذا الاختبارَ أوّلَ مرّةٍ
      // يسأل `lock.enabled` مرّتين — وهو لا يمسّ الإعداداتِ بشيء، فكان
      // يمرّ ولو بقي زرُّ الإطفاء في مكانه. **وحارسٌ لا يمسّ ما يحرسه لا
      // يحرس.**
      //
      // **ويُسأل المفتاحُ لا النصّ:** `lock-toggle` كان مفتاحَ الزرّ،
      // فغيابُه هو الضمانة. ولو بقي بنصٍّ آخر لَمرّ بحثٌ عن «أطفئه».
      _phone(tester);
      await appLock.enable('1379');

      await tester.pumpWidget(_wrap(SettingsScreen(session: _session())));
      await _settle(tester);

      expect(find.byKey(const ValueKey('lock-toggle'), skipOffstage: false),
          findsNothing,
          reason: 'زرُّ الإطفاء باقٍ — والقفلُ يُفترض أنّه مفروض');
      expect(find.text('أطفئه', skipOffstage: false), findsNothing);
      expect(find.byKey(const ValueKey('lock-change-pin'), skipOffstage: false),
          findsOneWidget,
          reason: 'ذهب الإطفاءُ وذهب معه تبديلُ الرمز');
    });

    testWidgets('**والخروجُ وحدَه يُزيله**', (tester) async {
      // ولولا هذا لَبقي رمزُ من خرج قائماً، فيدخل صاحبٌ آخرُ بحسابه على
      // الجهاز نفسه فيجد رمزاً لا يعرفه.
      final lock = AppLock();
      await lock.enable('1379');
      await lock.forget();

      expect(lock.enabled, isFalse);
    });
  });

  group('**وتبديلُ الرمز من الإعدادات**', () {
    // **ولا يكفي أن تُقاس `verify` وحدَها.** كسرتُ حارسَ الرمز القديم في
    // `account_extras.dart` — شُيل السؤالُ كلُّه — **فبقيت الحزمةُ خضراء**،
    // لأنّ لا اختبارَ يمرّ من الشاشة. فهذه تمرّ منها كما يمرّ المستخدم.
    testWidgets('رمزٌ قديمٌ خاطئٌ لا يُبدّل شيئاً', (tester) async {
      _phone(tester);
      await appLock.enable('1379');

      await tester.pumpWidget(_wrap(SettingsScreen(session: _session())));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('lock-change-pin')));
      await _settle(tester);

      await _type(tester, '0000');
      await _settle(tester);

      expect(find.text('الرمز الحالي خاطئ.'), findsOneWidget,
          reason: 'قُبل رمزٌ قديمٌ خاطئ — فمن وجد الجوالَ مفتوحاً يقفله على صاحبه');
      // **والرمزُ القديمُ باقٍ.** رسالةٌ تظهر ورمزٌ يُبدَّل خلفها أسوأ.
      expect(await appLock.verify('1379'), isTrue);
    });

    testWidgets('**والصحيحُ يفتح خطوتي الضبط**', (tester) async {
      // **ولولا هذه لَمرّ حارسٌ يرفض كلَّ شيء.** رفضُ الخاطئ وحدَه يمرّ على
      // شاشةٍ لا تُبدّل الرمزَ أبداً.
      _phone(tester);
      await appLock.enable('1379');

      await tester.pumpWidget(_wrap(SettingsScreen(session: _session())));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('lock-change-pin')));
      await _settle(tester);

      await _type(tester, '1379');
      await _settle(tester);
      await _type(tester, '2468');
      await _settle(tester);
      await _type(tester, '2468');
      await _settle(tester);

      expect(await appLock.verify('2468'), isTrue, reason: 'لم يُبدَّل الرمز');
      expect(await appLock.verify('1379'), isFalse, reason: 'القديمُ ما زال يفتح');
    });
  });

  group('**وتبديلُ الرمز يسأل القديم**', () {
    testWidgets('يقبل الصحيحَ ويردّ الخاطئ', (tester) async {
      // ولولاه لَاستطاع من وجد الجوالَ مفتوحاً أن يضع رمزاً جديداً فيقفله
      // على صاحبه.
      final lock = AppLock();
      await lock.enable('1379');

      expect(await lock.verify('1379'), isTrue);
      expect(await lock.verify('0000'), isFalse);
    });

    testWidgets('**ولا يُعدّ التبديلُ محاولةً خاطئة**', (tester) async {
      // ولو عُدَّ لَأُخرج حسابُ من أخطأ خمساً وهو يبدّل رمزَه في إعداداته.
      final lock = AppLock();
      await lock.enable('1379');

      for (var i = 0; i < 6; i++) {
        await lock.verify('0000');
      }
      expect(lock.exhausted, isFalse, reason: 'عُدَّ التبديلُ محاولةَ فتح');
      expect(lock.enabled, isTrue);
    });
  });
}
