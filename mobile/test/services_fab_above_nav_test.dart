// زرُّ «خدمة جديدة» فوق الشريط الزجاجيّ لا خلفَه.
//
// ── ما شكا منه ─────────────────────────────────────────────────────────────
//
// «مشكلة، لم أستطع الوصول إلى خدمات» — ومعها لقطةٌ يُرى في أسفلها طرفُ
// الزرّ خلفَ الشريط.
//
// ── والعطبُ لم يكن في هذه الشاشة ──────────────────────────────────────────
//
// `ServicesScreen` سقّالةٌ داخل سقّالة القشرة، وزرُّها يقف على قاعها. ولمّا
// صار شريطُ المزوّد زجاجيّاً دخلت معه `extendBody` فامتدّ الجسمُ تحته —
// فصار قاعُ السقّالة الداخليّة قاعَ الجوال، ونزل الزرُّ خلفَ الزجاج.
//
// **فيُقاس هنا ما يقع هناك**: الشاشةُ في سقّالةٍ بـ`extendBody` وشريطٍ
// زجاجيٍّ تحتها — كما في `provider_shell.dart` بحرفه. ولو قِيست وحدَها بلا
// شريطٍ لَمرّ العطبُ كلَّ مرّة، فلا شيءَ يحجبها.
//
// ── ويُقاس بالهندسة لا بالوجود ────────────────────────────────────────────
//
// **الزرُّ موجودٌ في الشجرة في الحالين** — خلفَ الشريط وفوقه. فيُسأل: أقاعُه
// فوق أعلى الشريط؟ وهو الفرقُ بين أن يُضغط وألّا يُضغط.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/services.dart';
import 'package:aras/src/ui/kit.dart';

final _nav = <GlassNavItem>[
  const GlassNavItem(label: 'الطلبات', icon: Icons.inbox_outlined, activeIcon: Icons.inbox),
  const GlassNavItem(
    label: 'تقويمي',
    icon: Icons.event_note_outlined,
    activeIcon: Icons.event_note,
  ),
  const GlassNavItem(label: 'خدماتي', icon: Icons.sell_outlined, activeIcon: Icons.sell),
  const GlassNavItem(
    label: 'ملفي',
    icon: Icons.storefront_outlined,
    activeIcon: Icons.storefront,
  ),
];

Session _provider() => Session()
  ..userId = 'u1'
  ..appUserId = 'a1'
  ..providerId = 'demo-provider'
  ..loading = false;

MyService _service() => MyService(
      id: 's1',
      title: 'قاعة التاج',
      description: '',
      price: 850000,
      priceTo: null,
      unit: 'للحجز',
      depositPercent: 30,
      categoryId: 'c1',
      isActive: true,
    );

/// القشرةُ كما في `provider_shell.dart`: `extendBody` وشريطٌ زجاجيٌّ ملتصق.
Widget _shell(Widget body) => MaterialApp(
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
      body: body,
      bottomNavigationBar: GlassNavBar(index: 2, onSelect: (_) {}, items: _nav),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => demoMyServices = [_service()]);

  testWidgets('**قاعُ الزرّ فوق أعلى الشريط**', (tester) async {
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_shell(ServicesScreen(session: _provider())));
    await _settle(tester);

    final fab = tester.getRect(find.byType(FloatingActionButton));
    final bar = tester.getRect(find.byType(GlassNavBar));
    expect(fab.bottom, lessThanOrEqualTo(bar.top),
        reason: 'الزرُّ خلفَ الشريط — لا يُضغط');

    // **وحدٌّ من فوقُ أيضاً.** «فوق الشريط» وحدَها تقبل زرّاً طائراً في وسط
    // الشاشة — وقد وقع ذلك فعلاً حين جُمعت ثوابتُ الشريط فوق ما تقوله
    // السقّالةُ أصلاً، فارتفع الزرُّ ارتفاعَ الشريط مرّتين ومرّ الاختبار.
    expect(bar.top - fab.bottom, lessThan(40),
        reason: 'الزرُّ طائرٌ بعيداً فوق الشريط');
  });

  testWidgets('**ويُضغط فتُفتح ورقةُ الخدمة الجديدة**', (tester) async {
    // **ولا يُسأل الموضعُ وحدَه**: زرٌّ في موضعه الصحيح قد يحجبه غيرُه.
    // فيُضغط ضغطاً حقيقيّاً ويُسأل: أفُتحت الورقة؟
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_shell(ServicesScreen(session: _provider())));
    await _settle(tester);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'خدمة جديدة'));
    await _settle(tester);

    expect(find.byKey(const ValueKey('service-category-field')), findsOneWidget,
        reason: 'لم تُفتح ورقةُ «خدمة جديدة» بالضغط');
  });
}
