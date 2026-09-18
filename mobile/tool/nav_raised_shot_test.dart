// **تصويرُ ما صار** — شريطُ التنقّل بقرصه المرتفع في الشاشتين.
//
//   SHOTS=<مجلّد> flutter test tool/nav_raised_shot_test.dart
//
// ── وهذه لقطةُ الشريط المشحون لا رسمٌ يشبهه ────────────────────────────────
//
// `GlassNavBar` نفسُها التي تُبنى في `customer_shell.dart` و
// `provider_shell.dart`، ببنودهما وأيقوناتهما بحرفها، بثيمة التطبيق
// (`buildTheme()`). **ولا شيءَ هنا مُعادُ البناء** — بخلاف راسم المقترح قبله.
//
// **وتحت الشريط لوحٌ ملوّنٌ عمداً**: الزجاجُ لا يُرى زجاجاً على بياض، ولولا
// ما يموّهه لَبدا ورقةً باهتةً وقيل «لم يتغيّر شيء».
//
// **ويُصوَّر كلُّ تبويبٍ مختاراً على حدة**: القرصُ يقع في خانته، فلو قُيس
// الأوّلُ وحدَه لَمرّ انزياحُ الأخير — وهو أضيقُ خاناتِ الشريط في العربية.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/theme.dart';
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

Widget _wrap(Widget child) => RepaintBoundary(
      key: const ValueKey('shot'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Directionality(textDirection: TextDirection.rtl, child: child),
        ),
      ),
    );

/// بنودُ العميل كما في `customer_shell.dart` بحرفها.
final _customer = <GlassNavItem>[
  GlassNavItem(label: tr('الرئيسية'), icon: Icons.home_outlined, activeIcon: Icons.home),
  GlassNavItem(
    label: tr('حجوزاتي'),
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long,
  ),
  GlassNavItem(label: tr('استكشف'), icon: Icons.search_outlined, activeIcon: Icons.search),
  GlassNavItem(
    label: tr('خطة العرس'),
    icon: Icons.fact_check_outlined,
    activeIcon: Icons.fact_check,
  ),
  GlassNavItem(label: tr('حسابي'), icon: Icons.person_outline, activeIcon: Icons.person),
];

/// وبنودُ المزوّد كما في `provider_shell.dart` بحرفها.
final _provider = <GlassNavItem>[
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

Widget _caption(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    );

/// لوحٌ ملوّنٌ تحت الشريط — **ليُرى الزجاجُ زجاجاً**.
Widget _stage(Widget bar) => Container(
      height: 150,
      color: AppColors.surface2,
      child: Stack(
        children: [
          Positioned(
            top: 4,
            right: Space.lg,
            left: Space.lg,
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: bar),
        ],
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('الشريطُ المشحونُ في الشاشتين', (tester) async {
    tester.view.physicalSize = const Size(1180, 2000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(
      ColoredBox(
        color: AppColors.surface2,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _caption('العميل — و«الرئيسية» مختارة'),
            _stage(GlassNavBar(index: 0, onSelect: (_) {}, items: _customer)),
            _caption('وهو نفسُه و«حسابي» مختارة — أضيقُ خانةٍ في الشريط'),
            _stage(GlassNavBar(index: 4, onSelect: (_) {}, items: _customer)),
            _caption('مقدّم الخدمة — وكان شريطاً مادّيّاً فصار زجاجاً مثلَه'),
            _stage(GlassNavBar(index: 0, onSelect: (_) {}, items: _provider)),
            _caption('وهو نفسُه و«ملفي» مختارة'),
            _stage(GlassNavBar(index: 3, onSelect: (_) {}, items: _provider)),
            const SizedBox(height: Space.lg),
          ],
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GlassNavBar), findsNWidgets(4));
    expect(tester.takeException(), isNull);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/nav-raised-shipped.png');
  });
}
