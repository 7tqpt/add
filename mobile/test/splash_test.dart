// شاشةُ الانطلاق — الشعارُ المتحرّك.
//
// طلب صاحبُ المنصّة شعاراً نبيذيّاً متحرّكاً لحظةَ فتح التطبيق، وقال: «قبل
// تنفيذ جيب لي فديوه وسالني». فعُرض عليه فيديوٌ بخيارين قبل أن يُلمَس
// `lib/`، فاختار **(أ) نبضٌ وتوهّج**.
//
// ── وأخطرُ أربعةٍ تُقاس هنا ─────────────────────────────────────────────────
//
// **١) المشهدُ واحدٌ لا مشهدان.** شاشةُ الإقلاع ثمّ شاشةُ الترحيب ترسمان
// العلامةَ نفسَها. فلو بدأت كلٌّ من أوّلها لَرُئي المشهدُ يُقطع في منتصفه
// ويُستأنف من الصفر — وهذا بعينه ما منع القوسَ من شاشة الإقلاع قبل اليوم.
//
// **٢) ولا تُحبس الشاشةُ ولا جزءاً من ثانية.** حركةٌ تُجمّل فتحةً واحدةً
// وتؤخّر كلَّ فتحةٍ بعدها ضريبةٌ يوميّة.
//
// **٣) والعلامةُ تسبق كلَّ شيء.** أكثرُ الإقلاعات تنتهي قبل نصف الثانية،
// فعلامةٌ تبدأ بعدها لا يراها أحد.
//
// **٤) ولا دوّارَ يومض.** من عاد تحقّقُه سريعاً لا يرى دوّاراً — والشاشةُ
// التي تومض في كلّ فتحةٍ تُقرأ متعثّرةً وإن كانت أسرعَ من غيرها.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/welcome.dart';
import 'package:aras/src/ui/kit.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: buildTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(textDirection: TextDirection.rtl, child: child),
  ),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// شفافيّةُ أوّلِ `AnimatedOpacity`/`Opacity` فوق [of].
double _opacityOf(WidgetTester tester, Finder of) {
  final widget = tester.widget(of);
  if (widget is AnimatedOpacity) return widget.opacity;
  return (widget as Opacity).opacity;
}

/// الشفافيّةُ **المرسومةُ فعلاً** — لا المطلوبة.
///
/// **والفرقُ بينهما هو كلُّ ما يُقاس هنا:** `AnimatedOpacity` تُطلب إليها ١
/// فتُعطيها بعد ربع ثانية. فسؤالُ الحقل عن قيمته يقول «ظهر» وهو لم يظهر بعد.
double _paintedOpacity(WidgetTester tester, Finder of) => tester
    .widget<FadeTransition>(find.descendant(
      of: of,
      matching: find.byType(FadeTransition),
    ))
    .opacity
    .value;

void main() {
  setUp(resetIntroClock);

  group('المشهد', () {
    testWidgets('**ولا ومضةَ بيضاءَ في أوّل إطار**', (tester) async {
      // أوّلُ ما يُرى من التطبيق كلِّه.
      _phone(tester);
      await tester.pumpWidget(_wrap(const BootScreen()));
      await tester.pump();

      expect(find.byType(BrandBackdrop), findsOneWidget);
    });

    testWidgets('**والعلامةُ تظهر قبل نصف ثانية**', (tester) async {
      // **ودالّةٌ صافيةٌ تُسأل مباشرةً.** ما يُحسب داخل `builder` لا يُعرف
      // إلّا بقراءة البكسلات.
      //
      // أكثرُ الإقلاعات تنتهي قبل نصف الثانية: فعلامةٌ تبدأ بعدها لا يراها
      // أحدٌ، ويبقى فاتحُ التطبيق ينظر إلى أرضيّةٍ فارغة.
      final atHalfSecond = 500 / introDuration.inMilliseconds;
      expect(BootScreen.markAt(atHalfSecond), greaterThan(0.9),
          reason: 'العلامةُ تتأخّر عن أكثر الإقلاعات فلا تُرى');
      expect(BootScreen.markAt(0), 0);
      expect(BootScreen.markAt(1), 1);
    });

    testWidgets('والاسمُ يصعد بعدها لا معها', (tester) async {
      // مشهدٌ له ترتيب: العلامةُ أوّلاً ثمّ اسمُها.
      expect(BootScreen.nameAt(0.2), 0);
      expect(BootScreen.nameAt(1), 1);
      expect(BootScreen.nameAt(0.5), lessThan(BootScreen.markAt(0.5)));
    });

    testWidgets('والعلامةُ والاسمُ يُرسمان فعلاً', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const BootScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('فرحتي'), findsOneWidget);
    });
  });

  // ==========================================================================
  //  الدوّار — لمن طال انتظارُه وحدَه
  // ==========================================================================

  group('الدوّار', () {
    testWidgets('**ولا يومض في وجه من عاد تحقّقُه سريعاً**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const BootScreen()));
      await tester.pump();
      expect(_opacityOf(tester, find.byKey(const ValueKey('boot-slow'))), 0);

      // **ودفعتان لا دفعةٌ واحدة.** لو انكشف الدوّارُ داخلَ الدفعة الأولى
      // لَبدأ تدرّجُه في إطارها الأخير وقيمتُه بعدُ صفر — فتقرأ الدفعةُ
      // الواحدةُ «لم يظهر» وهو يظهر. فتُدفع أخرى ويُقاس بعدها.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_paintedOpacity(tester, find.byKey(const ValueKey('boot-slow'))), 0,
          reason: 'ومض الدوّارُ في وجه من عاد تحقّقُه في جزءٍ من ثانية');
    });

    testWidgets('ويُكشف مع سطره لمن طال انتظارُه', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const BootScreen()));
      await tester.pump();
      // المؤقّتُ يُفجَّر أوّلاً، ثمّ تُمهَل الشفافيّةُ لتمشي — دفعةٌ واحدةٌ
      // كبيرةٌ تُفجّره وتترك التدرّجَ عند أوّله.
      await tester.pump(BootScreen.slowAfter);
      await tester.pump(const Duration(milliseconds: 400));

      expect(_paintedOpacity(tester, find.byKey(const ValueKey('boot-slow'))), 1);
      expect(find.byType(BrandSpinner), findsOneWidget);
      expect(find.text('جارٍ التحقق…'), findsOneWidget);
    });

    testWidgets('والسطرُ يُبدَّل حين يُمرَّر', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const BootScreen(label: 'جارٍ التحديث…')));
      await tester.pump();
      await tester.pump(BootScreen.slowAfter);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('جارٍ التحديث…'), findsOneWidget);
      expect(find.text('جارٍ التحقق…'), findsNothing);
    });
  });

  // ==========================================================================
  //  ساعةٌ واحدةٌ للشاشتين
  // ==========================================================================

  group('المشهدُ لا يُعاد', () {
    testWidgets('**فالترحيبُ يُستأنَف من حيث وقف الإقلاع**', (tester) async {
      // **وهذا أخطرُ ما هنا.** كان القوسُ ممنوعاً من شاشة الإقلاع لهذا
      // السبب بعينه: حركةٌ تُقطع ثمّ تُستأنف من الصفر تُقرأ تعثّراً.
      //
      // **والزمنُ حقيقيٌّ لا زمنُ الاختبار:** الساعةُ تقرأ `DateTime.now()`،
      // و`pump(Duration)` لا يحرّكها. فيُنتظر انتظاراً حقيقيّاً.
      _phone(tester);
      await tester.pumpWidget(_wrap(const BootScreen()));
      await tester.pump();

      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 400)));

      await tester.pumpWidget(_wrap(WelcomeScreen(session: Session())));
      await tester.pump();

      final arch = tester.widget<ArchMark>(find.byType(ArchMark));
      expect(arch.t.value, greaterThan(0.1),
          reason: 'أُعيد المشهدُ من الصفر — فيُرى مرّتين');
    });

    testWidgets('ومن بدأ عنده المشهدُ يبدأ من الصفر', (tester) async {
      // الساعةُ لا تمضي قبل أن يسألها أحد — وإلّا وجد أوّلُ فاتحٍ للتطبيق
      // المشهدَ منتهياً.
      expect(introProgress(), 0);
    });

    testWidgets('**وتقليلُ الحركة يُسكّن المشهدَ كلَّه**', (tester) async {
      // من طلب من جهازه تقليلَ الحركة طلبه لسببٍ — دوارٌ أو صداع.
      _phone(tester);
      await tester.pumpWidget(_wrap(const BootScreen(), reduceMotion: true));
      await tester.pump();

      // العلامةُ كاملةٌ من أوّل إطارٍ لا صاعدة.
      final opacity = tester.widget<Opacity>(find.ancestor(
        of: find.byType(Image),
        matching: find.byType(Opacity),
      ));
      expect(opacity.opacity, 1);
    });
  });
}
