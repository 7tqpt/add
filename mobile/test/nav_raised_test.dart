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

  group('المسافةُ تحت المحتوى', () {
    test('**تكفي الشريطَ وقرصَه معاً**', () {
      // ولو بقيت على قدر الشريط وحدَه لَحجب القرصُ آخرَ سطرٍ في كلّ قائمة.
      expect(glassNavSpace, greaterThanOrEqualTo(GlassNavBar.barHeight + GlassNavBar.raise),
          reason: 'المسافةُ أقصرُ من الشريط مع قرصه');
    });
  });
}
