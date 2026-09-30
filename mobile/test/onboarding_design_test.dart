// «أكمل ملفك» على صورة صاحب المنصّة — «نفذها كما هي».
//
// **وما يُقاس هنا ما يُرى وما يصل**: البطاقةُ بحافّتها المرتفعة في إطار
// شاشات الباب، والاسمُ في القوس لا يغيب تحتها، والقلبُ يمينَ الشخص،
// و«+967» بجانب الرقم — **وما يصل الخادمَ من الرقم** لا ما يعرضه الحقل.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/phone.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/onboarding.dart';
import 'package:aras/src/ui/auth_frame.dart';

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

Session _session() => Session()
  ..userId = 'u-new'
  ..email = 'new@sdd.company'
  ..loading = false;

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrap(OnboardingScreen(session: _session())));
  await _settle(tester);
}

/// يملأ النموذجَ بالرقم [phone] ويضغط «متابعة».
Future<void> _submit(WidgetTester tester, String phone) async {
  await tester.enterText(find.byType(TextField).at(0), 'محمد الصنعاني');
  await tester.enterText(find.byType(TextField).at(1), phone);
  await tester.tap(find.byKey(const ValueKey('governorate-field')));
  await _settle(tester);
  await tester.tap(find.text(demoGovernorates[0].name).last);
  await _settle(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'متابعة'));
  await _settle(tester);
}

void main() {
  setUp(demoResetProfile);

  group('الشكل', () {
    testWidgets('**في إطار شاشات الباب، برأسٍ أقصر وحافّةٍ مرتفعة**', (tester) async {
      await _open(tester);
      final frame = tester.widget<AuthFrame>(find.byType(AuthFrame));
      expect(frame.compact, isTrue);
      expect(frame.crowned, isTrue);
      final card = tester.widget<Container>(find.byKey(const ValueKey('auth-card')));
      expect((card.decoration! as ShapeDecoration).shape, isA<CrownedCardBorder>());
      for (final t in ['أكمل ملفك', 'أهلاً بك', 'فرحتي']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
    });

    testWidgets('**و«فرحتي» في القوس لا يغيب تحت البطاقة**', (tester) async {
      // **وغاب ذيلُ «ي» تحتها في أوّل لقطة** — الرأسُ القصيرُ لم يُترك فيه
      // تحت الاسم ما يسعه.
      //
      // **ويُقاس فراغٌ تحته لا مجرّدُ أنّه لا يلمسها**: ذيلُ «ي» في خطّ
      // التطبيق ينزل تحت مربّع السطر نفسِه، فمربّعٌ يقف عند حدّ البطاقة
      // تماماً يُخفي الذيلَ وهو «لا يلمسها». وقد مرّ الأوّلُ على هذا
      // والعيبُ قائم، فأسقطه ضابطٌ سالب.
      await _open(tester);
      final name = tester.getRect(find.text('فرحتي'));
      final card = tester.getRect(find.byKey(const ValueKey('auth-card')));
      expect(card.top - name.bottom, greaterThanOrEqualTo(12),
          reason: 'لا يبقى تحت الاسم إلّا ${card.top - name.bottom} لذيل «ي»');
    });

    testWidgets('**والقلبُ يمينَ الشخص لا يسارَه**', (tester) async {
      await _open(tester);
      final badge = find.byKey(const ValueKey('profile-badge'));
      final person = tester.getCenter(
        find.descendant(of: badge, matching: find.byIcon(Icons.person_outline_rounded)),
      );
      final heart = tester.getCenter(
        find.descendant(of: badge, matching: find.byIcon(Icons.favorite_rounded)),
      );
      expect(heart.dx, greaterThan(person.dx), reason: 'القلبُ يسارَ الشخص');
      expect(heart.dy, greaterThan(person.dy), reason: 'القلبُ فوق الشخص');
    });

    testWidgets('**ورموزُ الحقول في أوّلها — يمينَها**', (tester) async {
      await _open(tester);
      for (final (i, icon) in [(0, Icons.person_outline_rounded), (1, Icons.phone_outlined)]) {
        final field = tester.getRect(find.byType(TextField).at(i));
        final at = tester.getCenter(
          find.descendant(of: find.byType(TextField).at(i), matching: find.byIcon(icon)),
        );
        expect(at.dx, greaterThan(field.center.dx), reason: '$icon في آخر حقله');
      }
    });

    testWidgets('**و«تسجيل الخروج» داخلَ البطاقة**', (tester) async {
      await _open(tester);
      final card = tester.getRect(find.byKey(const ValueKey('auth-card')));
      final out = tester.getRect(find.text('تسجيل الخروج'));
      expect(card.contains(out.center), isTrue);
    });
  });

  group('مفتاحُ الدولة', () {
    testWidgets('**اليمنُ ابتداءً**', (tester) async {
      await _open(tester);
      expect(find.byKey(const ValueKey('dial-label')), findsOneWidget);
      expect(find.text('+967'), findsOneWidget);
      expect(find.byType(YemenFlag), findsOneWidget);
    });

    testWidgets('**والسهمُ يفتح شيئاً** — يمنٌ أو دولةٌ أخرى', (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('dial-picker')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('dial-967')), findsOneWidget);
      expect(find.byKey(const ValueKey('dial-other')), findsOneWidget);
    });

    for (final (typed, stored) in [
      ('771234567', '+967771234567'),
      ('0771234567', '+967771234567'),
      ('+966512345678', '+966512345678'),
    ]) {
      testWidgets('**«$typed» يصل الخادمَ «$stored»**', (tester) async {
        // **ولا يُسأل الحقلُ عمّا يعرضه** — يُسأل الملفُّ عمّا وصله.
        await _open(tester);
        await _submit(tester, typed);
        expect(demoProfile()?.phone, stored);
      });
    }

    testWidgets('**و«دولة أخرى» يُسقط المفتاحَ ويُحترم ما كُتب**', (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('dial-picker')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('dial-other')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('dial-label')), findsNothing);
      expect(find.byKey(const ValueKey('dial-other-mark')), findsOneWidget);

      await _submit(tester, '+201012345678');
      expect(demoProfile()?.phone, '+201012345678');
    });

    testWidgets('**و«دولة أخرى» برقمٍ بلا مفتاحٍ لا يصل الخادم**', (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('dial-picker')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('dial-other')));
      await _settle(tester);

      final before = demoProfile()?.phone;
      await _submit(tester, '771234567');
      expect(demoProfile()?.phone, before, reason: 'نُسب إلى اليمن رقمٌ قيل إنّه من دولةٍ أخرى');
      expect(find.textContaining('مفتاح الدولة'), findsOneWidget);
    });
  });

  group('جمعُ الرقم إلى مفتاحه', () {
    test('**المحلّيُّ يُسبَق بالمفتاح ويُسقط صفرُه**', () {
      expect(composePhone('967', '771234567'), '+967771234567');
      expect(composePhone('967', '0771 234 567'), '+967771234567');
      expect(composePhone('967', '٧٧١٢٣٤٥٦٧'), '+967771234567');
    });

    test('**وما كُتب بمفتاحه لا يُلصق به مفتاحٌ ثانٍ**', () {
      expect(composePhone('967', '+966512345678'), '+966512345678');
      expect(composePhone('967', '00966512345678'), '+966512345678');
    });

    test('والناقصُ يُردّ', () {
      expect(composePhone('967', '77123456'), isNull);
      expect(composePhone('967', '0'), isNull);
      expect(composePhone('967', ''), isNull);
    });

    test('**و«دولة أخرى» تطلب المفتاحَ مكتوباً — ولا تنسب الرقمَ إلى اليمن**', () {
      expect(composePhone(null, '+201012345678'), '+201012345678');
      expect(composePhone(null, '00201012345678'), '+201012345678');
      expect(composePhone(null, '771234567'), isNull);
      // وهو ما كان `normalisePhone` يفعله وحدَه — فالفرقُ مقيس.
      expect(normalisePhone('771234567'), '+967771234567');
    });
  });
}
