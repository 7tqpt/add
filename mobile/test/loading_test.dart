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
  //  شاشةُ البداية
  // ==========================================================================

  group('شاشةُ البداية', () {
    double archProgress(WidgetTester tester) => (tester
            .widget<CustomPaint>(find
                .descendant(
                    of: find.byType(ArchMark), matching: find.byType(CustomPaint))
                .first)
            .painter! as ArchPainter)
        .progress;

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

      await tester.pumpAndSettle();
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

      await tester.pumpAndSettle();
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
