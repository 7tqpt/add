// الاحتفال: القصاصاتُ والقلبُ ولوحُ التهنئة.
//
// **وأثقلُ ما يُقاس هنا شيئان لا يظهران في لقطة:**
//
//   ١. **أنّ القصاصات لا تبتلع اللمس.** طبقةٌ فوق الشاشة تلتقط الأصابع
//      تجعل صاحبَها يضغط «تمّ» فلا يقع شيء — فيظنّ التطبيقَ معلَّقاً وهو
//      يحتفل به. وهذا لا يُرى بالعين أبداً.
//   ٢. **وأنّها تُطفأ لمن طلب.** ومن تدوخه الحركةُ لا يُنثر في وجهه ثلاثٌ
//      وثلاثون قصاصةً متطايرة.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/ui/celebrate.dart';

Widget _wrap(Widget child, {bool still = false}) => MaterialApp(
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, home) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: Directionality(textDirection: TextDirection.rtl, child: home!),
      ),
      home: child,
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  // ==========================================================================
  //  **اللمسُ يمرّ**
  // ==========================================================================

  testWidgets('**والزرُّ تحت القصاصات يُضغط وهي تتساقط**', (tester) async {
    _phone(tester);
    var taps = 0;
    await tester.pumpWidget(_wrap(Scaffold(
      body: Stack(children: [
        Center(
          child: FilledButton(onPressed: () => taps++, child: const Text('تمّ')),
        ),
        const Positioned.fill(child: Confetti()),
      ]),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('تمّ'));
    expect(taps, 1, reason: 'ابتلعت القصاصاتُ اللمسة');
    await tester.pumpAndSettle();
  });

  // ==========================================================================
  //  **الإطفاء**
  // ==========================================================================

  group('تقليلُ الحركة', () {
    testWidgets('**لا قصاصةَ واحدة**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
          _wrap(const Scaffold(body: Confetti()), still: true));
      await tester.pump();
      // **ويُسأل عمّا تحت `Confetti` وحدها.** `Scaffold` و`Material` تضعان
      // `CustomPaint` من عندهما، فسؤالٌ عامٌّ يجدها فيسقط الاختبارُ على
      // شيءٍ لا يخصّه — وقد سقط.
      expect(
        find.descendant(
            of: find.byType(Confetti), matching: find.byType(CustomPaint)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('والقلبُ يُعرض ساكناً لا غائباً', (tester) async {
      // **ولا يُحذف:** القلبُ خبرٌ («تمّ حجزك»)، والحركةُ زينتُه. فمن أطفأ
      // الزينةَ لا يُحرم الخبر.
      _phone(tester);
      await tester.pumpWidget(
          _wrap(const Scaffold(body: Center(child: BeatingHeart())), still: true));
      await tester.pump();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      // وكذلك هنا: `Transform` يقع في شجرة Material نفسِها.
      expect(
        find.descendant(
            of: find.byType(BeatingHeart), matching: find.byType(Transform)),
        findsNothing,
        reason: 'نبض وقد طُلب الإطفاء',
      );
    });

    testWidgets('ولوحُ التهنئة يبقى بنصّه', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(
        const Scaffold(body: CelebrationOverlay(title: 'تمّ حجزك')),
        still: true,
      ));
      await tester.pump();
      expect(find.text('تمّ حجزك'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });
  });

  // ==========================================================================
  //  القصاصات
  // ==========================================================================

  group('القصاصات', () {
    testWidgets('**تُركَّب وتتحرّك ثمّ تسكن بلا استثناء**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const Scaffold(body: Confetti())));
      await tester.pump();
      for (final ms in [100, 400, 1200, 2000]) {
        await tester.pump(Duration(milliseconds: ms));
        expect(tester.takeException(), isNull, reason: 'رمت عند $ms');
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('**ولا تسرّب مؤقّتاً إن أُغلقت الشاشةُ وهي تتساقط**',
        (tester) async {
      // شاشةُ التهنئة يُغلقها صاحبُها بعد نصف ثانية، والمؤقّتُ يبقى يعمل
      // لولا `dispose`.
      _phone(tester);
      await tester.pumpWidget(_wrap(const Scaffold(body: Confetti())));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(_wrap(const Scaffold(body: Text('شاشةٌ أخرى'))));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });
  });

  // ==========================================================================
  //  القلب
  // ==========================================================================

  group('القلب', () {
    testWidgets('**ينبض نبضةً واحدةً ثمّ يستقرّ على حجمه**', (tester) async {
      // ما ينبض بلا انقطاع يسحب البصرَ إليه أبداً فيمنع قراءةَ ما حوله.
      _phone(tester);
      await tester.pumpWidget(
          _wrap(const Scaffold(body: Center(child: BeatingHeart()))));
      await tester.pump();

      double scale() {
        final t = tester.widget<Transform>(find
            .descendant(
                of: find.byType(BeatingHeart), matching: find.byType(Transform))
            .first);
        return t.transform.getMaxScaleOnAxis();
      }

      await tester.pump(const Duration(milliseconds: 300));
      expect(scale(), greaterThan(1.0), reason: 'لم ينبض');

      await tester.pumpAndSettle();
      expect(scale(), closeTo(1.0, 0.02), reason: 'لم يستقرّ على حجمه');
    });
  });

  // ==========================================================================
  //  الزهرة
  // ==========================================================================

  group('الزهرة', () {
    testWidgets('**تتفتّح ثمّ تستقرّ**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
          _wrap(const Scaffold(body: Center(child: BloomingFlower()))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'لم تستقرّ');
    });

    testWidgets('**ولمن أطفأ الحركةَ تُرسم متفتّحةً لا غائبة**', (tester) async {
      // غيابُها يترك فراغاً في التخطيط يُقرأ عطباً.
      _phone(tester);
      await tester.pumpWidget(_wrap(
          const Scaffold(body: Center(child: BloomingFlower())), still: true));
      await tester.pump();
      expect(
        find.descendant(
            of: find.byType(BloomingFlower), matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: find.byType(BloomingFlower),
            matching: find.byType(AnimatedBuilder)),
        findsNothing,
        reason: 'تحرّكت وقد طُلب الإطفاء',
      );
    });
  });

  // ==========================================================================
  //  لوحُ التهنئة
  // ==========================================================================

  testWidgets('ولوحُ التهنئة يعرض عنوانَه ونصَّه وزرَّه', (tester) async {
    _phone(tester);
    var taps = 0;
    await tester.pumpWidget(_wrap(Scaffold(
      body: CelebrationOverlay(
        title: 'تمّ حجزك',
        body: 'وصلك تأكيدٌ في الإشعارات.',
        action: FilledButton(
          onPressed: () => taps++,
          child: const Text('إلى حجوزاتي'),
        ),
      ),
    )));
    await tester.pump();
    expect(find.byKey(const ValueKey('celebrate-title')), findsOneWidget);
    expect(find.text('وصلك تأكيدٌ في الإشعارات.'), findsOneWidget);

    // **والزرُّ يُضغط والقصاصاتُ فوقه** — وهو مقصدُ الاختبار الأوّل مُعاداً
    // على اللوح نفسِه لا على تركيبٍ مصنوعٍ في الاختبار.
    await tester.tap(find.text('إلى حجوزاتي'));
    expect(taps, 1);
    await tester.pumpAndSettle();
  });
}
