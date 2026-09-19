// **عطبٌ ومُقترَحُ إصلاحه.** زرُّ «خدمة جديدة» صار خلفَ شريط التنقّل.
//
//   SHOTS=<مجلّد> flutter test tool/services_fab_fix_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما شكا منه ─────────────────────────────────────────────────────────────
//
// «مشكلة، لم أستطع الوصول إلى خدمات» — ومعها لقطةٌ يُرى في أسفلها طرفُ شيءٍ
// أبيضَ خلفَ الشريط. وهو زرُّ «خدمة جديدة».
//
// ── والعطبُ من تغييرٍ سابقٍ لي لا من الشاشة ───────────────────────────────
//
// `ServicesScreen` سقّالةٌ داخل سقّالة القشرة، وزرُّها العائمُ يقف على قاع
// سقّالته. ولمّا صار شريطُ المزوّد زجاجيّاً دخلت معه `extendBody`، فامتدّ
// الجسمُ **تحت** الشريط — فصار قاعُ السقّالة الداخليّة قاعَ الشاشة، ونزل
// الزرُّ خلفَ الزجاج.
//
// **وهو في هذه الشاشة وحدَها**: الأزرارُ العائمةُ الثلاثةُ الأخرى (العناوين،
// وطرق الدفع، والمستندات) في شاشاتٍ تُفتح طريقاً لا شريطَ تحتها.
//
// ── والمقترحُ: يُرفع الزرُّ بمقدار الشريط ──────────────────────────────────
//
// `glassNavSpace` هي ارتفاعُ الشريط وقرصِه وخطِّ النظام — وهي نفسُها التي
// تُنهي بها القوائمُ محتواها. فيُرفع الزرُّ بها، لا برقمٍ يُكتب بيده يبقى
// على قدره القديم يومَ يتغيّر الشريط.
//
// ── وما فيه حقيقيّ ────────────────────────────────────────────────────────
//
// `ServicesScreen` المشحونةُ بخدماتها التجريبيّة، و`GlassNavBar` المشحونةُ
// ببنود المزوّد — وكلاهما في سقّالةٍ بـ`extendBody` كما في `provider_shell`
// بحرفه. **واللقطةُ الأولى هي العطبُ كما هو اليوم**، والثانيةُ الزرُّ
// مرفوعاً.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/services.dart';
import 'package:aras/src/ui/kit.dart';

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(File(p).readAsBytes().then(ByteData.sublistView));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  await _load('IBMPlexSansArabic', [
    for (final w in ['400', '500', '600', '700'])
      'assets/fonts/IBMPlexSansArabic-$w.ttf',
  ]);
  await _load('NotoNaskhArabic', ['assets/fonts/NotoNaskhArabic-Regular.ttf']);
  final icons = File(
      '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) await _load('MaterialIcons', [icons.path]);
}

Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

final _nav = <GlassNavItem>[
  GlassNavItem(label: tr('الطلبات'), icon: Icons.inbox_outlined, activeIcon: Icons.inbox),
  GlassNavItem(
    label: tr('تقويمي'),
    icon: Icons.event_note_outlined,
    activeIcon: Icons.event_note,
  ),
  GlassNavItem(label: tr('خدماتي'), icon: Icons.sell_outlined, activeIcon: Icons.sell),
  GlassNavItem(
    label: tr('ملفي'),
    icon: Icons.storefront_outlined,
    activeIcon: Icons.storefront,
  ),
];

Session _provider() => Session()
  ..userId = 'u1'
  ..appUserId = 'a1'
  ..providerId = 'demo-provider'
  ..loading = false;

/// القشرةُ كما في `provider_shell.dart`: `extendBody` وشريطٌ زجاجيٌّ ملتصق.
Widget _shell({required Widget body}) => MaterialApp(
      debugShowCheckedModeBanner: false,
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

MyService _service(String id, String title) => MyService(
      id: id,
      title: title,
      description: '',
      price: 850000,
      priceTo: null,
      unit: 'للحجز',
      depositPercent: 30,
      categoryId: 'c1',
      isActive: true,
    );

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    demoMyServices = [
      _service('s1', 'قاعة التاج'),
      _service('s2', 'قاعة الندى'),
    ];
  });

  testWidgets('اليومَ — الزرُّ خلفَ الشريط', (tester) async {
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('shot'),
      child: _shell(body: ServicesScreen(session: _provider())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    final fab = tester.getRect(find.byType(FloatingActionButton));
    final bar = tester.getRect(find.byType(GlassNavBar));
    // **وهذا هو العطبُ مقيساً**: قاعُ الزرّ داخلَ الشريط.
    expect(fab.bottom, greaterThan(bar.top),
        reason: 'الزرُّ فوق الشريط — فلا عطبَ يُصوَّر');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/services-fab-today.png');
  });

  testWidgets('المقترحُ — الزرُّ مرفوعٌ فوق الشريط', (tester) async {
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // **الرفعُ بثوابت الشريط لا برقمٍ يُكتب بيده**: ارتفاعُه وقرصُه وخطُّ
    // النظام تحته. ورقمٌ منسوخٌ هنا يبقى على قدره القديم يومَ يتغيّر الشريط.
    //
    // **والزرُّ وحدَه مُعادُ البناء** — لا سبيلَ إلى لفّ زرّ `ServicesScreen`
    // من خارجها بلا تغييرٍ في `lib/`. وهو `FloatingActionButton.extended`
    // نفسُه بنصّه، في سقّالةٍ بـ`extendBody` وشريطٍ مشحون.
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('shot'),
      child: _shell(
        body: Builder(
          builder: (context) => Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom +
                    GlassNavBar.barHeight +
                    GlassNavBar.raise,
              ),
              child: FloatingActionButton.extended(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: Text(tr('خدمة جديدة')),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(
                  Space.lg, Space.lg, Space.lg, glassNavSpace),
              children: [
                for (final s in demoMyServices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.md),
                    child: AppCard(children: [SectionTitle(s.title)]),
                  ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/services-fab-fixed.png');
  });
}
