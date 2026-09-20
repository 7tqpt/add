// شريطُ التنقّل — المختارُ يرتفع في قرصٍ نبيذيّ، والشاشتان تتشاركانه.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// أرسل شريطاً أيقونتُه المختارةُ في قرصٍ يعلوه، واختار (أ) من ثلاثٍ:
// «الزجاجُ يبقى كما هو، والمختارُ يرتفع في قرصٍ نبيذيّ». ثمّ: «نفّذها على
// مقدّم الخدمة» — وكان شريطُه `NavigationBar` مادّيّاً يفترق عن شريط العميل
// في أظهر ما في الشاشة.
//
// ── ويُقاس الارتفاعُ بالهندسة لا بالوجود ───────────────────────────────────
//
// قرصٌ موجودٌ في الشجرة قد يكون داخلَ الشريط لا فوقه — و**الارتفاعُ هو
// الطلبُ بعينه**. فيُسأل: أيعلو أعلى القرصِ أعلى الشريط؟
//
// ── وأخطرُ ما هنا: مسافةٌ لا تكفي ──────────────────────────────────────────
//
// الشريطُ يطفو والمحتوى يمرّ تحته، فلمّا زاد القرصُ ارتفاعَه وجب أن تزيد
// `glassNavSpace` معه. **ولو بقيت على قدرها لَحجب القرصُ آخرَ سطرٍ في كلّ
// قائمة** — وهو عيبٌ لا يظهر إلّا لمن بلغ آخرَ قائمته.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/ui/kit.dart';

final _items = <GlassNavItem>[
  const GlassNavItem(label: 'الرئيسية', icon: Icons.home_outlined, activeIcon: Icons.home),
  const GlassNavItem(
    label: 'حجوزاتي',
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long,
  ),
  const GlassNavItem(label: 'حسابي', icon: Icons.person_outline, activeIcon: Icons.person),
];

Widget _wrap({required int index, ValueChanged<int>? onSelect}) => MaterialApp(
  theme: buildTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      extendBody: true,
      body: const SizedBox.expand(),
      bottomNavigationBar: GlassNavBar(
        index: index,
        onSelect: onSelect ?? (_) {},
        items: _items,
      ),
    ),
  ),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('القرصُ المرتفع', () {
    testWidgets('**يعلو حافّةَ الشريط لا يقف داخلَه**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(index: 0));
      await tester.pumpAndSettle();

      final disc = tester.getRect(find.byIcon(Icons.home));
      // الشريطُ نفسُه: أيقونةُ جارٍ غيرِ مختارٍ تقع فيه.
      final neighbour = tester.getRect(find.byIcon(Icons.person_outline));

      expect(disc.center.dy, lessThan(neighbour.center.dy),
          reason: 'المختارُ لم يرتفع عن جيرانه');
    });

    testWidgets('**وللمختار وحدَه — لا قرصانِ في شريط**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(index: 1));
      await tester.pumpAndSettle();

      // الأيقونةُ المصمتةُ للمختار وحدَه، وغيرُها مفرَّغة.
      expect(find.byIcon(Icons.receipt_long), findsOneWidget);
      expect(find.byIcon(Icons.home), findsNothing);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    });

    testWidgets('**ويُضغط القرصُ كما تُضغط الخانة**', (tester) async {
      // ولولا ذلك لَصار المختارُ وحدَه لا يُضغط — وهو أكبرُ هدفٍ في الشريط.
      _phone(tester);
      var tapped = -1;
      await tester.pumpWidget(_wrap(index: 0, onSelect: (i) => tapped = i));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();
      expect(tapped, 0, reason: 'القرصُ لا يستجيب للضغط');
    });

    testWidgets('**وكلماتُ الجيران باقية**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(index: 0));
      await tester.pumpAndSettle();

      expect(find.text('حجوزاتي'), findsOneWidget);
      expect(find.text('حسابي'), findsOneWidget);
    });
  });

  group('عائمٌ بهامش', () {
    // ── ونقضٌ لاختيارٍ سابقٍ بطلب صاحبه ───────────────────────────────────
    //
    // كان ملتصقاً بالحافّة («خليه جزء من التطبيق»)، فلمّا أرسل شريطاً ذا
    // حفرةٍ وقال «أريد نفس الاستايل» عُرضت عليه الحالان مفرَّقتين — ومعهما
    // التنبيهُ أنّ العائمَ ينقض طلبَه السابق — فاختار (ج): عائمٌ بالأسماء.
    //
    // ── ولا يُقاس الصندوقُ الخارجيّ ────────────────────────────────────────
    //
    // **وهذا عيبٌ وقع فعلاً**: كان الاختبارُ القديمُ يقيس `GlassNavBar` نفسَها
    // ويسأل أتبلغ حافّةَ الشاشة. وهي تبلغها في الحالين — الهامشُ داخلَها —
    // فمرّ الاختبارُ بعد التحويل إلى العائم وهو يحرس ما لم يعد قائماً.
    // **فيُقاس الزجاجُ المقصوصُ نفسُه.**
    Finder glass() => find.descendant(
          of: find.byType(GlassNavBar),
          matching: find.byType(ClipPath),
        );

    testWidgets('**الزجاجُ لا يبلغ حافّةَ الشاشة**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(index: 0));
      await tester.pumpAndSettle();

      final bar = tester.getRect(glass());
      final screen = tester.getRect(find.byType(MaterialApp));
      expect(bar.left - screen.left, GlassNavBar.sideMargin, reason: 'لا هامشَ يساراً');
      expect(screen.right - bar.right, GlassNavBar.sideMargin, reason: 'لا هامشَ يميناً');
      expect(screen.bottom - bar.bottom, greaterThanOrEqualTo(GlassNavBar.bottomGap),
          reason: 'لا فرجةَ تحته');

      // **ولا يُقاس الهامشُ بالثابت الذي صنعه وحدَه.** السطورُ فوقُ تقول
      // «ما قِيس يساوي ما كُتب» — وهي صادقةٌ ولو صار المكتوبُ صفراً، فيعود
      // ملتصقاً والحزمةُ خضراء. **وقد وقع ذلك فعلاً**: كُسر الثابتُ إلى صفرٍ
      // في الضابط السالب فلم يسقط. فيُحدُّ الرقمُ نفسُه.
      expect(GlassNavBar.sideMargin, greaterThanOrEqualTo(12),
          reason: 'الهامشُ الجانبيُّ ذهب — عاد ملتصقاً بالحافّة');
      expect(GlassNavBar.bottomGap, greaterThanOrEqualTo(6),
          reason: 'الفرجةُ السفليّةُ ذهبت — عاد واقفاً على حافّة الشاشة');
    });

    testWidgets('**وأيقوناتُه بالمقاس الذي اختير**', (tester) async {
      // ثلاثةٌ تتحرّك معاً — ولو صُغّر أحدُها وحدَه لَاختلّت نسبتُه.
      _phone(tester);
      await tester.pumpWidget(_wrap(index: 0));
      await tester.pumpAndSettle();

      final neighbour = tester.widget<Icon>(find.byIcon(Icons.person_outline));
      expect(neighbour.size, GlassNavBar.iconSize);
      expect(GlassNavBar.iconSize, lessThan(21), reason: 'لم تصغر عمّا كانت');
    });
  });

  group('الحفرةُ حول القرص', () {
    // ── ولا يُسأل الشكلُ عن وجوده ─────────────────────────────────────────
    //
    // `ClipPath` في الشجرة لا تعني أنّ ثَمّ حفرة: قد تقصّ مستطيلاً مستديراً
    // لا غير. **فيُسأل المسارُ نفسُه**: أيقع ما تحت مركز القرص خارجَه؟
    //
    // وهذا ممكنٌ بلا كشفِ الصنف: `ClipPath.clipper` نوعُها `CustomClipper<Path>`
    // و`getClip` عليها — فيُقاس ما يقصّ لا اسمُ من يقصّ.

    (Path, Rect) clip(WidgetTester tester) {
      final finder = find.descendant(
        of: find.byType(GlassNavBar),
        matching: find.byType(ClipPath),
      );
      final rect = tester.getRect(finder);
      final clipper = tester.widget<ClipPath>(finder).clipper!;
      return (clipper.getClip(rect.size), rect);
    }

    testWidgets('**الزجاجُ مقصوصٌ تحت القرص**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(index: 1));
      await tester.pumpAndSettle();

      final (path, rect) = clip(tester);
      final disc = tester.getRect(find.byIcon(Icons.receipt_long));
      // مركزُ القرص بإحداثيّات الزجاج.
      final cx = disc.center.dx - rect.left;

      // نقطةٌ تحت مركز القرص بقليل: لو لم تُقصّ لَكانت زجاجاً.
      expect(path.contains(Offset(cx, GlassNavBar.raise + 4)), isFalse,
          reason: 'لا حفرةَ تحت القرص — الزجاجُ متّصل');
      // وعلى حافّة الشريط بعيداً عنه: زجاجٌ كما يجب.
      //
      // **ولا يُجَسُّ المنتصف**: البنودُ ثلاثةٌ والمختارُ أوسطُها، فمنتصفُ
      // الشريط هو الحفرةُ بعينها. ويُجَسُّ طرفُه — بعدَ ركنه المستدير.
      expect(path.contains(Offset(rect.width * 0.15, GlassNavBar.raise + 4)), isTrue,
          reason: 'الشريطُ مقصوصٌ حيث لا قرص');
    });

    testWidgets('**والفرجةُ أوسعُ من القرص**', (tester) async {
      // ولولا ذلك لَلامست حافّةُ الحفرة القرصَ فلم يُرَ جالساً فيها.
      _phone(tester);
      await tester.pumpWidget(_wrap(index: 1));
      await tester.pumpAndSettle();

      final (path, rect) = clip(tester);
      final disc = tester.getRect(find.byIcon(Icons.receipt_long));
      final cx = disc.center.dx - rect.left;

      // نقطةٌ على حافّة القرص تماماً — وهي داخلَ الحفرة لا في الزجاج.
      expect(
        path.contains(Offset(cx + GlassNavBar.discSize / 2 + 2, GlassNavBar.raise)),
        isFalse,
        reason: 'الحفرةُ على قدر القرص فلا فرجةَ بينهما',
      );
      expect(GlassNavBar.notchGap, greaterThan(0));
    });

    testWidgets('**ومركزُ القرص على حافّة الشريط**', (tester) async {
      // نصفُه فوقها ونصفُه في حفرته — وعليه بُنيت الحفرةُ نفسُها.
      _phone(tester);
      await tester.pumpWidget(_wrap(index: 0));
      await tester.pumpAndSettle();

      // **و`ClipPath` تملأ الكومةَ فأعلاها أعلى القرص لا أعلى الزجاج** —
      // والزجاجُ يبدأ في مسارها على بُعد `raise`. فيُقاس من أعلى الودجة.
      final box = tester.getRect(find.descendant(
        of: find.byType(GlassNavBar),
        matching: find.byType(ClipPath),
      ));
      final disc = tester.getRect(find.byIcon(Icons.home));
      expect((disc.center.dy - box.top - GlassNavBar.raise).abs(), lessThan(1.5),
          reason: 'القرصُ ليس على الحافّة');
    });

    testWidgets('**والحفرةُ تتبع المختارَ لا تقف في مكانها**', (tester) async {
      // قصٌّ مربوطٌ بخانةٍ ثابتةٍ يترك المختارَ على زجاجٍ متّصلٍ وحفرةً فارغة.
      _phone(tester);
      await tester.pumpWidget(_wrap(index: 0));
      await tester.pumpAndSettle();
      final (first, rect) = clip(tester);

      await tester.pumpWidget(_wrap(index: 2));
      await tester.pumpAndSettle();
      final (third, _) = clip(tester);

      final probe = Offset(
        tester.getRect(find.byIcon(Icons.person)).center.dx - rect.left,
        GlassNavBar.raise + 4,
      );
      expect(first.contains(probe), isTrue, reason: 'الحفرةُ في غير مكان المختار');
      expect(third.contains(probe), isFalse, reason: 'الحفرةُ لم تتبع المختار');
    });
  });

  group('المسافةُ تحت المحتوى', () {
    test('**تكفي الشريطَ وقرصَه وهامشَه معاً**', () {
      // ولو بقيت على قدر الشريط وحدَه لَحجب القرصُ آخرَ سطرٍ في كلّ قائمة.
      // **والهامشُ السفليُّ معه**: الشريطُ صار عائماً، فتحته فرجةٌ تُحسب.
      expect(
        glassNavSpace,
        greaterThanOrEqualTo(
          GlassNavBar.barHeight + GlassNavBar.raise + GlassNavBar.bottomGap,
        ),
        reason: 'المسافةُ أقصرُ من الشريط مع قرصه وهامشه',
      );
    });
  });
}
