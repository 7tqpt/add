// حركةُ الواجهة.
//
// **وأثقلُ ما يُقاس هنا أنّ الحركةَ تُطفأ.** في أندرويد وآيفون إعدادٌ اسمه
// «تقليل الحركة» يشغّله من تدوخه الحركة — وتطبيقٌ يتجاهله يُدير رأسَ صاحبه
// في كلّ شاشة. وهو إعدادٌ **لا يراه من يبني التطبيق أبداً** ما لم يشغّله
// في جهازه، فحارسُه اختبارٌ أو لا شيء.
//
// ويُقاس معه أنّ التدرّج **محدود**: قائمةٌ فيها مئتا بطاقةٍ لو أُخّرت كلُّ
// واحدةٍ عن أختها لَظهرت الأخيرةُ بعد ثماني ثوانٍ.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/ui/motion.dart';

Widget _wrap(
  Widget child, {
  bool still = false,
  TextDirection dir = TextDirection.rtl,
}) =>
    MaterialApp(
      theme: buildTheme(),
      locale: Locale(dir == TextDirection.rtl ? 'ar' : 'en'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, home) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: Directionality(textDirection: dir, child: home!),
      ),
      home: child,
    );

/// شفافيّةُ `Opacity` الذي يلفّ نصّاً بعينه.
///
/// **ولا يُؤخذ أوّلُ `Opacity` في الشجرة.** السمةُ والقشرةُ تضعان شفافيّاتٍ
/// من عندهما، فـ`.first` قد يقع على واحدةٍ منها لا على التي تُقاس — وهو
/// خطأٌ يمرّ صامتاً لأنّ قيمتَها ‎١٫٠‎ غالباً، فيبدو الاختبارُ ناجحاً.
double _opacityOf(WidgetTester tester, String text) => tester
    .widget<Opacity>(find
        .ancestor(of: find.text(text), matching: find.byType(Opacity))
        .first)
    .opacity;

/// انزلاقُ الشاشة التي تحمل نصّاً بعينه.
///
/// **وكذلك هنا:** Flutter يضع للشاشة **الخارجة** انزلاقاً من عنده، فـ
/// `find.byType(SlideTransition).first` يقع عليه لا على انزلاقنا — وقيمتُه
/// صفرٌ، فتقرأ الأزرقَ أحمرَ. سقط الاختبارُ عليه قبل أن يُشدّ.
Offset _slideOf(WidgetTester tester, String text) => tester
    .widget<SlideTransition>(find
        .ancestor(of: find.text(text), matching: find.byType(SlideTransition))
        .first)
    .position
    .value;

void main() {
  // ==========================================================================
  //  **الإطفاء**
  // ==========================================================================

  group('تقليلُ الحركة', () {
    testWidgets('**يظهر العنصرُ كاملاً من أوّل إطار**', (tester) async {
      // ولولا هذا لَرآه من أطفأ الحركةَ يتلاشى ويصعد كما لو لم يطفئ شيئاً.
      await tester.pumpWidget(_wrap(
        const Scaffold(body: FadeSlideIn(child: Text('أهلاً'))),
        still: true,
      ));
      await tester.pump();
      expect(_opacityOf(tester, 'أهلاً'), 1.0);
    });

    testWidgets('ولا ينتظر دورَه في التدرّج', (tester) async {
      await tester.pumpWidget(_wrap(
        const Scaffold(
          body: FadeSlideIn(index: 7, child: Text('أهلاً')),
        ),
        still: true,
      ));
      await tester.pump();
      expect(_opacityOf(tester, 'أهلاً'), 1.0, reason: 'أُخّر وقد طُلب الإطفاء');
    });

    testWidgets('**ولا ينخفض الزرُّ تحت الإصبع**', (tester) async {
      await tester.pumpWidget(_wrap(
        Scaffold(body: Pressable(onTap: () {}, child: const Text('اضغط'))),
        still: true,
      ));
      final gesture = await tester.startGesture(tester.getCenter(find.text('اضغط')));
      await tester.pump(Motion.fast);
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.0);
      await gesture.up();
    });

    testWidgets('وطريقُ الشاشة يصل بلا انزلاق', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(
                      builder: (_) =>
                          const Scaffold(body: Text('الثانية')))),
              child: const Text('اذهب'),
            ),
          ),
        ),
        still: true,
      ));
      await tester.tap(find.text('اذهب'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.ancestor(
            of: find.text('الثانية'), matching: find.byType(SlideTransition)),
        findsNothing,
        reason: 'انزلقت وقد طُلب الإطفاء',
      );
      await tester.pumpAndSettle();
      expect(find.text('الثانية'), findsOneWidget);
    });
  });

  // ==========================================================================
  //  الظهورُ المتدرّج
  // ==========================================================================

  group('الظهورُ المتدرّج', () {
    testWidgets('**يبدأ خفيّاً ثمّ يكتمل**', (tester) async {
      await tester.pumpWidget(_wrap(
        const Scaffold(body: FadeSlideIn(child: Text('أهلاً'))),
      ));
      await tester.pump();
      expect(_opacityOf(tester, 'أهلاً'), 0.0);
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'أهلاً'), 1.0);
    });

    testWidgets('**والمتأخّرُ يبقى خفيّاً بينما ظهر الأوّل**', (tester) async {
      await tester.pumpWidget(_wrap(
        const Scaffold(
          body: Column(children: [
            FadeSlideIn(index: 0, child: Text('الأولى')),
            FadeSlideIn(index: 8, child: Text('الثامنة')),
          ]),
        ),
      ));
      // ــ ثلاثُ نبضاتٍ لا اثنتان، ولها سبب ــــــــــــــــــــــــــــــــ
      //
      // **مؤقّتُ الأولى يقع في آخر النبضة لا في أوّلها.** فلو نُبض ‎٣٠٠‎ دفعةً
      // واحدةً لَوقع المؤقّتُ عند نهايتها ورُسم الإطارُ وقيمتُها صفر — وهو
      // ما وقع لي: قرأتُ «الأولى لم تكتمل» فظننتُ التدرّجَ مكسوراً، وإنّما
      // كانت ساعةُ الاختبار.
      //
      // وعلى الجهاز لا أثرَ لهذا: الإطاراتُ تتوالى كلَّ ‎١٦‎ جزءاً من الألف،
      // فالتأخيرُ إطارٌ واحدٌ لا يُرى.
      //
      // ولحظةُ القياس فيها فسحةٌ عمداً: الأولى تستغرق ‎٢٦٠‎، والثامنة لا
      // تبدأ قبل ‎٣٦٠‎ — فالقياسُ عند ‎٣٠٠‎ يقع بينهما.
      await tester.pump();                    // بناءٌ أوّل: تُجدوَل المؤقّتات
      await tester.pump(Duration.zero);       // يقع مؤقّتُ الأولى
      await tester.pump(const Duration(milliseconds: 300));
      expect(_opacityOf(tester, 'الأولى'), 1.0, reason: 'الأولى لم تكتمل');
      expect(_opacityOf(tester, 'الثامنة'), lessThan(1.0),
          reason: 'الثامنة سبقت دورَها');
      await tester.pumpAndSettle();
    });

    testWidgets('**والتدرّجُ محدود — الخمسون كالثامنة**', (tester) async {
      // ولولا الحدّ لَانتظر صاحبُ قائمةٍ طويلةٍ ثوانيَ أمام فراغ.
      await tester.pumpWidget(_wrap(
        const Scaffold(
          body: Column(children: [
            FadeSlideIn(index: 8, child: Text('الثامنة')),
            FadeSlideIn(index: 50, child: Text('الخمسون')),
          ]),
        ),
      ));
      await tester.pump();
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 45 * 8));
      await tester.pump(Motion.normal);
      expect(_opacityOf(tester, 'الثامنة'), 1.0);
      expect(_opacityOf(tester, 'الخمسون'), 1.0,
          reason: 'الخمسون تأخّرت عن الثامنة');
      await tester.pumpAndSettle();
    });

    testWidgets('ولا يرمي إن أُغلقت الشاشةُ قبل دوره', (tester) async {
      // الأخيرةُ في قائمةٍ يخرج منها صاحبُها بعد جزءٍ من ثانية.
      await tester.pumpWidget(_wrap(
        const Scaffold(body: FadeSlideIn(index: 8, child: Text('متأخّرة'))),
      ));
      await tester.pump();
      await tester.pumpWidget(_wrap(const Scaffold(body: Text('شاشةٌ أخرى'))));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });

  // ==========================================================================
  //  اللمسة
  // ==========================================================================

  group('اللمسة', () {
    testWidgets('**تنخفض تحت الإصبع وترجع عند الرفع**', (tester) async {
      await tester.pumpWidget(_wrap(
        Scaffold(body: Pressable(onTap: () {}, child: const Text('اضغط'))),
      ));
      double scale() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
      expect(scale(), 1.0);

      final gesture = await tester.startGesture(tester.getCenter(find.text('اضغط')));
      await tester.pump();
      expect(scale(), lessThan(1.0));

      await gesture.up();
      await tester.pump();
      expect(scale(), 1.0);
    });

    testWidgets('**وما لا يُضغط لا ينخفض**', (tester) async {
      // بطاقةٌ للعرض لا للفتح تُوهم صاحبَها أنّ فيها شيئاً إن تحرّكت.
      await tester.pumpWidget(_wrap(
        const Scaffold(body: Pressable(child: Text('عرضٌ فقط'))),
      ));
      final gesture = await tester.startGesture(tester.getCenter(find.text('عرضٌ فقط')));
      await tester.pump();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.0);
      await gesture.up();
    });

    testWidgets('وإلغاءُ اللمسة يُرجعها', (tester) async {
      await tester.pumpWidget(_wrap(
        Scaffold(body: Pressable(onTap: () {}, child: const Text('اضغط'))),
      ));
      final gesture = await tester.startGesture(tester.getCenter(find.text('اضغط')));
      await tester.pump();
      await gesture.cancel();
      await tester.pump();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.0);
    });

    testWidgets('واللمسةُ تصل فتُنادى', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        Scaffold(body: Pressable(onTap: () => taps++, child: const Text('اضغط'))),
      ));
      await tester.tap(find.text('اضغط'));
      expect(taps, 1);
    });
  });

  // ==========================================================================
  //  **طريقُ الشاشة والاتّجاه**
  // ==========================================================================

  // **ويُدفع `MaterialPageRoute` عاديٌّ عمداً — لا مساعدٌ من عندنا.**
  // الانتقالُ مركَّبٌ في السمة، فما يُقاس هنا أنّ **كلَّ** دفعةٍ في التطبيق
  // تأخذه — بما فيها السبعةُ والأربعون القائمة وما يُكتب غداً. ولو قِيس
  // مساعدٌ خاصٌّ لَما قال ذلك شيئاً.
  group('طريقُ الشاشة', () {
    Future<Offset> slideFrom(WidgetTester tester, TextDirection dir) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(
                      builder: (_) =>
                          const Scaffold(body: Text('الثانية')))),
              child: const Text('اذهب'),
            ),
          ),
        ),
        dir: dir,
      ));
      await tester.tap(find.text('اذهب'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      final offset = _slideOf(tester, 'الثانية');
      await tester.pumpAndSettle();
      return offset;
    }

    testWidgets('**في العربيّة تأتي من اليسار**', (tester) async {
      // القارئُ يتقدّم إلى اليسار، فالشاشةُ الجديدة تأتي من حيث يتوقّعها.
      expect((await slideFrom(tester, TextDirection.rtl)).dx, lessThan(0));
    });

    testWidgets('وفي الإنجليزيّة من اليمين', (tester) async {
      expect((await slideFrom(tester, TextDirection.ltr)).dx, greaterThan(0));
    });

    testWidgets('وتصل الشاشةُ في موضعها', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(
                      builder: (_) =>
                          const Scaffold(body: Text('الثانية')))),
              child: const Text('اذهب'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('اذهب'));
      await tester.pumpAndSettle();
      expect(_slideOf(tester, 'الثانية'), Offset.zero);
      expect(find.text('الثانية'), findsOneWidget);
    });
  });

  // ==========================================================================
  //  المددُ نفسُها
  // ==========================================================================

  test('**والمددُ مرتّبةٌ ومحسوسةٌ ولا تُنتظر**', () {
    expect(Motion.fast, lessThan(Motion.normal));
    expect(Motion.normal, lessThan(Motion.page));
    // ما دون ‎٨٠‎ لا يُحسّ، وما فوق ‎٤٥٠‎ يُنتظر.
    expect(Motion.fast.inMilliseconds, greaterThanOrEqualTo(80));
    expect(Motion.page.inMilliseconds, lessThanOrEqualTo(450));
  });
}
