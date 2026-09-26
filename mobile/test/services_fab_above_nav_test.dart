// زرُّ «خدمة جديدة» يُرى ويُضغط — لا يختفي خلفَ زجاج.
//
// ── ما شكا منه ─────────────────────────────────────────────────────────────
//
// «مشكلة، لم أستطع الوصول إلى خدمات» — ومعها لقطةٌ يُرى في أسفلها طرفُ
// الزرّ خلفَ الشريط السفليّ.
//
// ── والعطبُ لم يكن في هذه الشاشة ──────────────────────────────────────────
//
// `ServicesScreen` كانت سقّالةً داخل سقّالة القشرة، وزرُّها عائمٌ يقف على
// قاعها. ولمّا صار شريطُ المزوّد زجاجيّاً دخلت معه `extendBody` فامتدّ
// الجسمُ تحته — فصار قاعُ السقّالة الداخليّة قاعَ الجوال، ونزل الزرُّ خلفَ
// الزجاج.
//
// ── ثمّ بدّله صاحبُ المنصّة ────────────────────────────────────────────────
//
// أرسل تصميماً فيه **شريطٌ في صدر القائمة** لا زرٌّ عائمٌ في القاع. فذهب
// الزرُّ العائم وذهب معه بابُ العطب — **والضمانةُ باقيةٌ ومحلُّها انتقل**:
// كان الخطرُ أن يختفي خلفَ الزجاج السفليّ، وصار أن يختفي خلفَ الزجاج
// العلويّ. فيُقاس أنّه **تحت الرأس لا خلفه**، وأنّه **يُضغط فتُفتح الورقة**.
//
// ── ويُقاس بالهندسة لا بالوجود ────────────────────────────────────────────
//
// **الزرُّ موجودٌ في الشجرة في الحالين** — خلفَ الزجاج وتحته. فيُسأل عن
// موضعه لا عن وجوده.
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
      // الرأسُ في `Stack` كما في `provider_shell.dart` بحرفه: زجاجٌ يمتدّ
      // إلى الحافّة والمحتوى يمرّ تحته.
      body: GlassHeaderHost(title: 'خدماتي', tab: 2, child: body),
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

  testWidgets('**رأسُ الزرّ تحت الزجاج العلويّ**', (tester) async {
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_shell(ServicesScreen(session: _provider())));
    await _settle(tester);

    final button = tester.getRect(find.byKey(const ValueKey('new-service')));
    // ارتفاعُ الزجاج: شريطُ الحالة ثمّ الرأس — وهو ما تحجزه القائمةُ في
    // حشوتها العلويّة.
    final headerBottom = tester.view.padding.top / tester.view.devicePixelRatio +
        glassHeaderBar;
    expect(button.top, greaterThanOrEqualTo(headerBottom),
        reason: 'الزرُّ خلفَ الرأس الزجاجيّ — لا يُرى ولا يُضغط');

    // **وحدٌّ من تحتُ أيضاً**: «تحت الرأس» وحدَها تقبل زرّاً نزل إلى وسط
    // الشاشة أو خرج من الشاشة كلِّها.
    expect(button.top - headerBottom, lessThan(60),
        reason: 'الزرُّ بعيدٌ عن صدر القائمة');
  });

  testWidgets('**ويبقى لمن لا خدمةَ له** — وهي أوّلُ حالٍ يقع فيها',
      (tester) async {
    // **وهذا عطبٌ وقع في النقل**: جُعل الشريطُ أوّلَ صفٍّ في القائمة، فلمّا
    // لم تكن خدمةٌ لم تكن قائمةٌ — فاختفى معها البابُ الوحيدُ إلى الإضافة.
    // ومن سجّل للتوّ ليس له خدمةٌ بعد.
    demoMyServices = [];
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_shell(ServicesScreen(session: _provider())));
    await _settle(tester);

    expect(find.text('لا خدمات بعد'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-service')), findsOneWidget,
        reason: 'لا بابَ إلى الإضافة لمن لا خدمةَ له');
  });

  testWidgets('**ويُضغط فتُفتح ورقةُ الخدمة الجديدة**', (tester) async {
    // **ولا يُسأل الموضعُ وحدَه**: زرٌّ في موضعه الصحيح قد يحجبه غيرُه.
    // فيُضغط ضغطاً حقيقيّاً ويُسأل: أفُتحت الورقة؟
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_shell(ServicesScreen(session: _provider())));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('new-service')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('service-category-field')), findsOneWidget,
        reason: 'لم تُفتح ورقةُ «خدمة جديدة» بالضغط');
  });
}
