// **مقترحٌ لا تنفيذ.** خطٌّ فاصلٌ في الشريط السفليّ.
//
//   SHOTS=<مجلّد> flutter test tool/nav_hairline_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «أريد في الشريط السفليّ خطّ أسود خفيف يفصل بين أيقونة وشريط».
//
// و«يفصل بين أيقونة وشريط» يحتمل ثلاثةَ مواضعَ مختلفة، فتُعرض كلُّها:
// خطٌّ على حافّة الشريط العليا، أو خطٌّ ينقطع عند القرص المرتفع، أو خطوطٌ
// رأسيّةٌ تفصل كلَّ أيقونةٍ عن جارتها.
//
// ── وما فيه حقيقيٌّ وما هو مرسوم ──────────────────────────────────────────
//
// **حقيقيّ:** `GlassNavBar` المشحونةُ نفسُها ببنود المزوّد الخمسة — بزجاجها
// وتمويهها وقرصها وظلّها، لا صندوقٌ يشبهها.
//
// **ومرسومٌ يُقال:** الخطُّ مُركَّبٌ **فوقها** في كومةٍ لا مكتوبٌ فيها — لا
// سبيلَ إلى تغيير حافّتها من خارجها بلا تغييرٍ في `lib/`. وموضعُه محسوبٌ
// بثوابتها هي (`raise` و`barHeight`)، فهو حيث سيكون بالضبط.
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
          backgroundColor: AppColors.surface2,
          body: Directionality(textDirection: TextDirection.rtl, child: child),
        ),
      ),
    );

final _items = <GlassNavItem>[
  GlassNavItem(label: tr('الطلبات'), icon: Icons.inbox_outlined, activeIcon: Icons.inbox),
  GlassNavItem(label: tr('خدماتي'), icon: Icons.sell_outlined, activeIcon: Icons.sell),
  GlassNavItem(
    label: tr('تقويمي'),
    icon: Icons.event_note_outlined,
    activeIcon: Icons.event_note,
  ),
  GlassNavItem(
    label: tr('الرسائل'),
    icon: Icons.quickreply_outlined,
    activeIcon: Icons.quickreply_rounded,
  ),
  GlassNavItem(
    label: tr('ملفي'),
    icon: Icons.storefront_outlined,
    activeIcon: Icons.storefront,
  ),
];

const _selected = 3;

/// عرضُ اللوح — تُحسب به مواضعُ الخطوط بثوابت الشريط لا بالتقدير.
const double _w = 390;
const double _cell = _w / 5;
const double _stage = GlassNavBar.barHeight + GlassNavBar.raise;

Widget _line(Color c, {double h = 1}) => Container(height: h, color: c);

/// الشريطُ الحقيقيُّ ومعه الخطُّ مُركَّباً فوقه.
Widget _bar({required List<Widget> overlay}) => SizedBox(
      width: _w,
      height: _stage,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          GlassNavBar(index: _selected, onSelect: (_) {}, items: _items),
          ...overlay,
        ],
      ),
    );

Widget _panel(String number, String name, String note, Widget bar) => Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, 2),
            child: Row(
              children: [
                Text(
                  number,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      fontFamilyFallback: arabicFallback,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
            child: Text(
              note,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.muted,
                fontFamilyFallback: arabicFallback,
              ),
            ),
          ),
          Center(child: bar),
        ],
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('اللوح', (tester) async {
    tester.view.physicalSize = const Size(900, 2500);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    // «أسودُ خفيف» — حبرُ التطبيق بشفافيّة، لا أسودَ مصمتاً يقطع الزجاج.
    final ink10 = AppColors.ink.withValues(alpha: 0.10);

    // موضعُ القرص محسوبٌ بثوابت الشريط: الخانةُ الرابعةُ من اليمين في RTL.
    const centreFromRight = (_selected + 0.5) * _cell;
    const half = 28.0; // نصفُ القرص وهامشُه

    await tester.pumpWidget(_wrap(ListView(
      padding: const EdgeInsets.symmetric(vertical: Space.lg),
      children: [
        _panel('اليوم:', 'بلا خطّ', 'الظلُّ وحدَه يفصله عمّا فوقه',
            _bar(overlay: const [])),

        _panel(
          '(أ)',
          'خطٌّ على الحافّة العليا كلِّها',
          'يمرّ تحت القرص — أبسطُها وأقلُّها كلاماً',
          _bar(overlay: [
            Positioned(
              top: GlassNavBar.raise,
              left: 0,
              right: 0,
              child: _line(ink10),
            ),
          ]),
        ),

        _panel(
          '(ب)',
          'خطٌّ ينقطع عند القرص',
          'فيبدو القرصُ خارجاً من الشريط لا واقفاً عليه',
          _bar(overlay: [
            Positioned(
              top: GlassNavBar.raise,
              right: 0,
              width: centreFromRight - half,
              child: _line(ink10),
            ),
            Positioned(
              top: GlassNavBar.raise,
              left: 0,
              width: _w - centreFromRight - half,
              child: _line(ink10),
            ),
          ]),
        ),

        _panel(
          '(ج)',
          'خطوطٌ رأسيّةٌ بين الأيقونات',
          'تفصل كلَّ أيقونةٍ عن جارتها لا عن الشريط',
          _bar(overlay: [
            for (var k = 1; k < _items.length; k++)
              Positioned(
                top: GlassNavBar.raise + 20,
                right: k * _cell,
                width: 1,
                height: 26,
                child: ColoredBox(color: ink10),
              ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.sm),
          child: Text(
            tr('وكم يكون «خفيفاً»؟ — الشكلُ (أ) بثلاث درجات:'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontFamilyFallback: arabicFallback,
            ),
          ),
        ),
        for (final step in const [
          ('١ — خفيفٌ جدّاً (٦٪)', 0.06),
          ('٢ — متوسّط (١٢٪)', 0.12),
          ('٣ — ظاهرٌ (٢٠٪)', 0.20),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, 4),
                  child: Text(
                    step.$1,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.ink2,
                      fontFamilyFallback: arabicFallback,
                    ),
                  ),
                ),
                Center(
                  child: _bar(overlay: [
                    Positioned(
                      top: GlassNavBar.raise,
                      left: 0,
                      right: 0,
                      child: _line(AppColors.ink.withValues(alpha: step.$2)),
                    ),
                  ]),
                ),
              ],
            ),
          ),
      ],
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull, reason: 'فاض اللوحُ عن الشاشة');
    // الأشرطةُ السبعةُ كلُّها حقيقيّة — فلو سقط أحدُها لَخرجت اللوحةُ ناقصةً
    // وأنا أعرضها كاملة.
    expect(find.byType(GlassNavBar), findsNWidgets(7));

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/nav-hairline.png');
  });
}
