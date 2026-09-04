// الانتظارُ وشاشةُ البداية.
//
// **وثلاثةُ أشياءَ هنا لا تُرى في لقطةٍ ولا في تجربةٍ عابرة:**
//
//   ١. **أنّ الدوّار لا يقفز عند تمام دورته.** القفزةُ تقع مرّةً كلَّ ثانيةٍ
//      ونصف، فمن نظر إليه ثانيةً لم يرها ومن انتظر عشراً رآها سبعاً.
//   ٢. **أنّ كتلة الانتظار تسكت في أوّلها.** أكثرُ القراءات تعود في أقلّ من
//      عُشر ثانية، فدوّارٌ يظهر فوراً يومض ويختفي — والوميضُ يُقرأ تعثّراً.
//   ٣. **أنّ القوس الداخليّ يتأخّر عن الخارجيّ.** لولا ذلك رُسما خطّاً
//      واحداً سميكاً، وهو عطبٌ يُترجَم ويعمل ولا يقول شيئاً.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/welcome.dart';
import 'package:aras/src/ui/kit.dart';

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

/// نسبةُ الشفافيّة على عنصرٍ بعينه — و**تحت أصلٍ محدَّدٍ لا في الشجرة كلِّها**.
/// `Opacity` يقع في شجرة Material بالعشرات، وسؤالٌ عامٌّ يجد أوّلَها.
double _opacityOf(WidgetTester tester, Finder of) {
  final o = find.ancestor(of: of, matching: find.byType(AnimatedOpacity));
  if (o.evaluate().isNotEmpty) {
    return tester.widget<AnimatedOpacity>(o.first).opacity;
  }
  return tester
      .widget<Opacity>(
          find.ancestor(of: of, matching: find.byType(Opacity)).first)
      .opacity;
}

void main() {
  // ==========================================================================
  //  طورُ الدوّار — حسابٌ صافٍ يُسأل بلا بكسلات
  // ==========================================================================

  group('طورُ الدوّار', () {
    test('**لا يقصر القوسُ إلى صفرٍ ولا ينقلب سالباً**', () {
      // لو سبق الذيلُ الرأسَ لاختفى القوسُ لحظةً في كلّ دورة.
      for (var i = 0; i <= 100; i++) {
        final p = spinnerPhase(i / 100);
        expect(p.sweep, greaterThan(0), reason: 'اختفى عند ${i / 100}');
        expect(p.sweep, lessThan(2 * math.pi),
            reason: 'التفّ على نفسه عند ${i / 100}');
      }
    });

    test('**ويعود إلى حيث بدأ عند تمام الدورة**', () {
      final a = spinnerPhase(0);
      final b = spinnerPhase(1);
      expect(b.sweep, closeTo(a.sweep, 1e-9), reason: 'تبدّل الطولُ عند اللفّة');
      // الزاويةُ تُقاس بباقي الدورة: ‎٤π−π/٢‎ و‎−π/٢‎ موضعٌ واحد.
      double mod(double x) => (x % (2 * math.pi) + 2 * math.pi) % (2 * math.pi);
      expect(mod(b.start), closeTo(mod(a.start), 1e-9),
          reason: 'قفز الموضعُ عند اللفّة');
    });

    test('ويتقدّم ولا يرجع', () {
      var last = spinnerPhase(0).start;
      for (var i = 1; i <= 100; i++) {
        final s = spinnerPhase(i / 100).start;
        expect(s, greaterThanOrEqualTo(last - 1e-9), reason: 'رجع عند ${i / 100}');
        last = s;
      }
    });
  });

  // ==========================================================================
  //  الدوّار على الشاشة
  // ==========================================================================

  group('الدوّار', () {
    testWidgets('**يلفّ فعلاً — لا صورةً ساكنةً تُظنّ حركة**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const Scaffold(body: Center(child: BrandSpinner()))));
      await tester.pump();

      CustomPainter painter() => tester
          .widget<CustomPaint>(find
              .descendant(
                  of: find.byType(BrandSpinner), matching: find.byType(CustomPaint))
              .first)
          .painter!;

      final first = painter();
      await tester.pump(const Duration(milliseconds: 300));
      expect(painter().shouldRepaint(first), isTrue, reason: 'لم يتحرّك');
    });

    testWidgets('ولمن أطفأ الحركةَ قوسٌ ساكنٌ لا فراغ', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
          _wrap(const Scaffold(body: Center(child: BrandSpinner())), still: true));
      await tester.pump();
      expect(
        find.descendant(
            of: find.byType(BrandSpinner), matching: find.byType(CustomPaint)),
        findsOneWidget,
        reason: 'حُذف الدوّارُ فلم يبقَ ما يقول «ننتظر»',
      );
      expect(
        find.descendant(
            of: find.byType(BrandSpinner), matching: find.byType(AnimatedBuilder)),
        findsNothing,
        reason: 'لفّ وقد طُلب الإطفاء',
      );
      // ولا مقودَ يعمل: `pumpAndSettle` تُعلَّق إلى الأبد لو بقي يلفّ.
      await tester.pumpAndSettle();
    });

    testWidgets('ولا يسرّب مقوداً إن أُغلقت الشاشةُ وهو يلفّ', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const Scaffold(body: Center(child: BrandSpinner()))));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(_wrap(const Scaffold(body: Text('شاشةٌ أخرى'))));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });

  // ==========================================================================
  //  كتلةُ الانتظار
  // ==========================================================================

  group('كتلةُ الانتظار', () {
    testWidgets('**تسكت في أوّلها ثمّ تظهر**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const Scaffold(body: LoadingBlock())));
      await tester.pump();
      expect(_opacityOf(tester, find.byType(BrandSpinner)), 0,
          reason: 'ومض الدوّارُ فوراً — وأكثرُ القراءات تعود قبل ذلك');

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_opacityOf(tester, find.byType(BrandSpinner)), 1,
          reason: 'انتظر ولم يُعرض له شيء');
    });

    testWidgets('ومساحتُها محجوزةٌ قبل ظهورها', (tester) async {
      // لو بُني الفراغُ ثمّ حلّ محلَّه المحتوى لقفز ما حوله بعد خُمس ثانية.
      _phone(tester);
      await tester.pumpWidget(_wrap(const Scaffold(body: LoadingBlock())));
      await tester.pump();
      final before = tester.getSize(find.byType(BrandSpinner));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.getSize(find.byType(BrandSpinner)), before);
      expect(before.height, greaterThan(0));
    });

    testWidgets('ومن طلب ظهوراً فوريّاً أُعطيه', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(
          const Scaffold(body: LoadingBlock(delay: Duration.zero))));
      await tester.pump();
      expect(_opacityOf(tester, find.byType(BrandSpinner)), 1);
    });

    testWidgets('**ومؤقّتُها يُلغى إن أُغلقت قبل مهلته**', (tester) async {
      // وهذه الحالُ هي الغالبة لا النادرة: أكثرُ هذه الكتل تُبنى ثمّ تُرمى
      // قبل أن تحين مهلتُها.
      //
      // **ولا يُنتظر انقضاءُ المهلة هنا.** كانت الشاشةُ تُغلَق ثمّ يُدفع
      // الوقتُ ستّمئةَ مللٍّ فيفرغ المؤقّتُ من نفسه، فيُقاس أنّ `mounted`
      // يحرس لا أنّ المؤقّت أُلغي — وهما شيئان: الأوّلُ يمنع الرمي والثاني
      // يمنع بقاءَ المؤقّت. فيُترك المؤقّتُ معلّقاً حتى نهاية الاختبار،
      // وإطارُ الاختبار يسقطه إن بقي.
      _phone(tester);
      await tester.pumpWidget(_wrap(const Scaffold(body: LoadingBlock())));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(_wrap(const Scaffold(body: Text('وصلت'))));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('ونصُّها يُقرأ على أرضيّته', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const Scaffold(
          body: LoadingBlock(label: 'جارٍ التحقق…', labelColor: Colors.white70))));
      await tester.pump(const Duration(milliseconds: 700));
      final text = tester.widget<Text>(find.text('جارٍ التحقق…'));
      expect(text.style!.color, Colors.white70,
          reason: 'رماديُّ الأرضيّة الفاتحة على النبيذيّ لا يُقرأ');
    });
  });

  // ==========================================================================
  //  القوس
  // ==========================================================================

  group('القوس', () {
    test('**والداخليُّ يتأخّر عن الخارجيّ ولا يسبقه**', () {
      expect(ArchPainter.inner(0.0), 0);
      expect(ArchPainter.inner(0.25), 0);
      for (var i = 0; i <= 100; i++) {
        final outer = i / 100;
        expect(ArchPainter.inner(outer), lessThan(outer + 1e-9),
            reason: 'سبق الداخليُّ الخارجيَّ عند $outer');
      }
      expect(ArchPainter.inner(1), 1, reason: 'لم يكتمل الداخليّ');
    });

    test('ويُرسم مقدارُه من الطول لا من الإحداثيّات', () {
      // القيمةُ نفسُها لا تكفي: تُقاس أنّها محصورةٌ فلا يرمي `extractPath`.
      for (var i = -20; i <= 120; i++) {
        final v = ArchMark.archAt(i / 100);
        expect(v, inInclusiveRange(0, 1), reason: 'خرجت عند ${i / 100}');
      }
    });

    test('ويكتمل الرسمُ قبل نهاية المشهد', () {
      // القوسُ إطارٌ لما بعده، فاكتمالُه بعد ظهور الاسم يجعله يلحق بالنصّ.
      expect(ArchMark.archAt(0.62), 1);
      expect(ArchMark.archAt(0.30), lessThan(1));
      expect(ArchMark.archAt(0), 0);
    });
  });

  // ==========================================================================
  //  الحياة — حسابٌ صافٍ يُسأل بلا شاشة
  // ==========================================================================

  group('الذرّاتُ الذهبيّة', () {
    test('**تعود كلُّ ذرّةٍ إلى موضعها عند تمام الدورة**', () {
      // ولو كانت سرعةُ ذرّةٍ كسراً من الدورة لَقفزت عند تمامها — وأربعَ
      // عشرةَ ذرّةً تقفز معاً كلَّ تسع ثوانٍ تُرى ارتجاجةً في الشاشة كلِّها.
      for (var i = 0; i < 14; i++) {
        final a = moteAt(i, 0);
        final b = moteAt(i, 1);
        expect(b.x, closeTo(a.x, 1e-9), reason: 'قفزت أفقيّاً: $i');
        expect(b.y, closeTo(a.y, 1e-9), reason: 'قفزت رأسيّاً: $i');
        expect(b.alpha, closeTo(a.alpha, 1e-9), reason: 'ومضت: $i');
      }
    });

    test('**وتولد وتنطفئ في طرفَيها ولا تنبثق**', () {
      for (var i = 0; i < 14; i++) {
        // في لحظةِ ولادتها وموتها تكون معدومةَ الشفافيّة.
        final born = _birthOf(i);
        expect(moteAt(i, born).alpha, closeTo(0, 1e-6),
            reason: 'ظهرت الذرّةُ $i فجأةً');
      }
    });

    test('ولا تخرج ذرّةٌ عن حدود المنطقة', () {
      for (var i = 0; i < 14; i++) {
        for (var k = 0; k <= 60; k++) {
          final m = moteAt(i, k / 60);
          expect(m.x, inInclusiveRange(0, 1), reason: 'خرجت $i عند $k');
          expect(m.y, inInclusiveRange(0, 1), reason: 'خرجت $i عند $k');
          expect(m.alpha, inInclusiveRange(0, 1));
          expect(m.r, greaterThan(0));
        }
      }
    });

    test('**ولا تصعد كلُّها في صفٍّ واحدٍ ولا بسرعةٍ واحدة**', () {
      // ذرّاتٌ متساويةُ السرعة تُقرأ شبكةً تتحرّك لا غباراً في ضوء.
      final ys = {for (var i = 0; i < 14; i++) moteAt(i, 0.3).y.toStringAsFixed(3)};
      expect(ys.length, greaterThan(8), reason: 'اصطفّت الذرّاتُ في خطّ');
      final xs = {for (var i = 0; i < 14; i++) moteAt(i, 0.3).x.toStringAsFixed(2)};
      expect(xs.length, greaterThan(8), reason: 'اصطفّت في عمود');
    });
  });

  group('شريطُ الضوء', () {
    test('**يرتاح أكثرَ ممّا يمرّ**', () {
      // بريقٌ متّصلٌ يصير خلفيّةً متحرّكةً تسحب البصرَ عن الزرّ.
      var seen = 0;
      for (var i = 0; i < 200; i++) {
        final c = glintAt(i / 200);
        if (c != null && c > -0.18 && c < 1.18) seen++;
      }
      expect(seen / 200, lessThan(0.55), reason: 'لا يكاد يهدأ');
      expect(seen, greaterThan(0), reason: 'لا يمرّ أصلاً');
    });

    test('ويدخل من خارج الحافّة ويخرج من خارجها', () {
      // فلا يُرى يُولد في وسط الشاشة ولا ينقطع فيها.
      final first = glintAt(0)!;
      expect(first, lessThan(-0.18), reason: 'وُلد داخل الإطار');
      // آخرُ لحظةٍ من نصيب المرور — ‎٠٫٣٥‎ من نصف الدورة، أي ‎٠٫١٧٥‎ منها.
      final last = glintAt(0.1749)!;
      expect(last, greaterThan(1.18), reason: 'انقطع داخل الإطار');
    });

    test('ويمرّ مرّتين في الدورة لا مرّةً', () {
      // تسعُ ثوانٍ بين بريقٍ وبريقٍ طويلةٌ جدّاً، وأربعٌ ونصفٌ تُلاحَظ.
      var passes = 0;
      var wasOff = true;
      for (var i = 0; i <= 400; i++) {
        final c = glintAt(i / 400);
        final on = c != null && c > -0.18 && c < 1.18;
        if (on && wasOff) passes++;
        wasOff = !on;
      }
      expect(passes, 2);
    });
  });

  // ==========================================================================
  //  شاشةُ البداية
  // ==========================================================================

  group('شاشةُ البداية', () {
    // **ويُسأل عن رسّام القوس بعينه لا عن أوّل `CustomPaint`.** في العلامة
    // الآن رسّامان: الذرّاتُ خلفَ القوس، والقوسُ. والذرّاتُ أوّلُ ما تجده
    // `.first` — فيقرأ الاختبارُ رسّاماً لا يخصّه ويمرّ على كلّ حال.
    double archProgress(WidgetTester tester) => (tester
            .widget<CustomPaint>(find.byWidgetPredicate(
                (w) => w is CustomPaint && w.painter is ArchPainter))
            .painter! as ArchPainter)
        .progress;

    /// يمشي بالوقت إلى ما بعد نهاية مقود الدخول.
    ///
    /// **و`pumpAndSettle` لا تصلح هنا بعد اليوم:** الشاشةُ لا تسكن أبداً —
    /// وهذا هو المقصود منها، لا عطبٌ فيها.
    Future<void> enter(WidgetTester tester) =>
        tester.pump(const Duration(milliseconds: 1800));

    testWidgets('**يُرسم القوسُ متدرّجاً لا دفعةً واحدة**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(Scaffold(
        body: _Drive(builder: (t) => ArchMark(t: t)),
      )));
      await tester.pump();
      expect(archProgress(tester), 0, reason: 'ظهر القوسُ كاملاً في أوّل إطار');

      await tester.pump(const Duration(milliseconds: 500));
      final mid = archProgress(tester);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1), reason: 'اكتمل قبل أوانه');

      await enter(tester);
      expect(archProgress(tester), 1, reason: 'لم يكتمل');
    });

    testWidgets('**والاسمُ يظهر بعد القوس لا معه**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(Scaffold(
        body: _Drive(builder: (t) => ArchMark(t: t)),
      )));
      await tester.pump();

      // **ويُقاس في منتصف الرسم لا في أوّل إطار.** في أوّل إطارٍ كلُّ شيءٍ
      // صفرٌ مهما رُتّب المشهد، فقياسٌ هناك يمرّ ولو ظهر الاسمُ مع القوس.
      // والمقصودُ ترتيبٌ: أن يكون القوسُ قد بدأ والاسمُ لم يبدأ بعدُ.
      await tester.pump(const Duration(milliseconds: 260));
      expect(archProgress(tester), greaterThan(0), reason: 'لم يبدأ القوسُ بعد');
      expect(_opacityOf(tester, find.text('فرحتي')), 0,
          reason: 'ظهر الاسمُ مع القوس فلم يبقَ للمشهد ترتيب');

      await enter(tester);
      expect(_opacityOf(tester, find.text('فرحتي')), 1);
    });

    testWidgets('ولمن أطفأ الحركةَ تُعرض الشاشةُ تامّةً من أوّل إطار',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(
        Scaffold(body: _Drive(builder: (t) => ArchMark(t: t))),
        still: true,
      ));
      await tester.pump();
      expect(archProgress(tester), 1, reason: 'رُسم القوسُ وقد طُلب الإطفاء');
      expect(_opacityOf(tester, find.text('فرحتي')), 1);
      expect(find.text('كل خدمات زفافك في مكان واحد'), findsOneWidget);
      // ولا ذرّةَ تصعد، ولا مقودَ يدور: `pumpAndSettle` تُعلَّق لو بقي واحد.
      expect(find.byKey(const ValueKey('motes')), findsNothing);
      await tester.pumpAndSettle();
    });

    // ======================================================================
    //  **الحياة بعد الدخول**
    //
    //  وهذا هو المطلوبُ الذي لأجله كُتب هذا كلُّه: كانت الشاشةُ تحيا ثانيةً
    //  ونصفاً ثمّ تسكن سكوناً تامّاً — وصاحبُها يقف أمامها يقرأ ويقرّر،
    //  فيرى صورةً لا شاشة.
    // ======================================================================

    testWidgets('**تبقى الشاشةُ حيّةً بعد أن يستقرّ دخولُها**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(Scaffold(
        body: _Drive(builder: (t) => ArchMark(t: t)),
      )));
      await enter(tester);

      CustomPainter motes() => tester
          .widget<CustomPaint>(find.byKey(const ValueKey('motes')))
          .painter!;

      // مقودُ الدخول انتهى، والقوسُ اكتمل — ومع ذلك ما زال شيءٌ يتحرّك.
      expect(archProgress(tester), 1);
      final a = motes();
      await tester.pump(const Duration(milliseconds: 500));
      expect(motes().shouldRepaint(a), isTrue,
          reason: 'سكنت الشاشةُ بعد الدخول فصارت صورةً');
    });

    testWidgets('**وتبقى حيّةً بعد دقيقةٍ لا ثانيتين**', (tester) async {
      // **ودقيقةٌ لا ثانيتان عمداً:** `repeat()` قد تُوقف من حيث لا يُدرى —
      // بمقودٍ يُتلَف، أو بدورةٍ تنتهي ولا تُعاد. وقياسٌ بعد نصف ثانيةٍ لا
      // يفرّق بين حياةٍ باقيةٍ وحياةٍ ستنقطع بعد الدورة الأولى. والدورةُ
      // تسعُ ثوانٍ، فدقيقةٌ تقطع ستّاً منها.
      _phone(tester);
      await tester.pumpWidget(_wrap(Scaffold(
        body: _Drive(builder: (t) => ArchMark(t: t)),
      )));
      await enter(tester);
      await tester.pump(const Duration(seconds: 60));

      CustomPainter motes() => tester
          .widget<CustomPaint>(find.byKey(const ValueKey('motes')))
          .painter!;
      final a = motes();
      await tester.pump(const Duration(milliseconds: 400));
      expect(motes().shouldRepaint(a), isTrue,
          reason: 'ماتت الشاشةُ بعد دورةٍ أو دورتين');
    });

    testWidgets('**والبريقُ يُرسم فعلاً ثمّ يهدأ**', (tester) async {
      // **وحسابُه وحده لا يكفي.** في هذا المشروع ميزاتٌ حُسبت صحيحةً ولم
      // تُوصَل بشيء فبقيت ميّتةً شهوراً. فيُسأل عن الطبقة نفسِها على الشجرة:
      // أتظهر؟ ثمّ أتغيب؟
      _phone(tester);
      await tester.pumpWidget(_wrap(Scaffold(
        body: _Drive(builder: (t) => ArchMark(t: t)),
      )));
      await enter(tester);

      final glint = find.descendant(
          of: find.byType(ArchMark), matching: find.byType(ShaderMask));
      var seen = 0;
      var quiet = 0;
      // دورةٌ كاملةٌ بخطواتٍ من مئةٍ وخمسين مللٍّ.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 150));
        if (glint.evaluate().isEmpty) {
          quiet++;
        } else {
          seen++;
        }
      }
      expect(seen, greaterThan(0), reason: 'البريقُ يُحسب ولا يُرسم');
      expect(quiet, greaterThan(seen), reason: 'لا يكاد يهدأ');
    });

    testWidgets('**ولا تبتلع الذرّاتُ لمسةً تحتها**', (tester) async {
      // طبقةٌ فوق الشاشة تلتقط الأصابع تجعل صاحبَها يضغط فلا يقع شيء —
      // فيظنّ التطبيقَ معلَّقاً وهو يزيّن له. ولا يُرى هذا في لقطةٍ أبداً.
      //
      // والزرُّ في أسفل منطقة العلامة لا في وسطها: الوسطُ فيه الاسمُ نفسُه،
      // فتُقاس عندئذٍ عوازلُ النصّ لا طبقةُ الذرّات.
      _phone(tester);
      var taps = 0;
      await tester.pumpWidget(_wrap(Scaffold(
        body: Stack(children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: FilledButton(
              onPressed: () => taps++,
              child: const Text('ابدأ'),
            ),
          ),
          Positioned.fill(child: _Drive(builder: (t) => ArchMark(t: t))),
        ]),
      )));
      await enter(tester);
      await tester.tap(find.text('ابدأ'));
      expect(taps, 1, reason: 'ابتلعت الذرّاتُ اللمسة');
    });

    testWidgets('وشاشةُ الدخول لا تومض بالأبيض', (tester) async {
      // أوّلُ ما يُرى من التطبيق كلِّه — وأرضيّتُه نبيذيّةٌ من أوّل إطار.
      _phone(tester);
      await tester.pumpWidget(_wrap(const BootScreen()));
      await tester.pump();
      expect(find.byType(BrandBackdrop), findsOneWidget);
      expect(_opacityOf(tester, find.byType(BrandSpinner)), 0,
          reason: 'ومض الدوّارُ في وجه من عاد تحقّقُه في جزءٍ من ثانية');
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('جارٍ التحقق…'), findsOneWidget);
    });
  });
}

/// مقودٌ للاختبار — يسوق ما يُبنى فيه كما تسوقه شاشةُ الترحيب.
class _Drive extends StatefulWidget {
  const _Drive({required this.builder});
  final Widget Function(Animation<double> t) builder;

  @override
  State<_Drive> createState() => _DriveState();
}

class _DriveState extends State<_Drive> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_c);
}

/// لحظةُ ولادة الذرّة [i] من الدورة — حين تكون في أسفل المنطقة.
///
/// `p == 0` يقع حين `v * speed + phase` عددٌ صحيح.
double _birthOf(int i) {
  final phase = _frac(i * 0.7548776662);
  final speed = 1 + (i % 3);
  return (1 - phase) / speed;
}

double _frac(double x) => x - x.floorToDouble();
