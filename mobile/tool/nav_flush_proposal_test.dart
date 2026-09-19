// **مقترحٌ لا تنفيذ.** شريطُ التنقّل يلتصق بحافّتَي الشاشة وأسفلِها بدل أن
// يطفو بطاقةً فوقها.
//
//   SHOTS=<مجلّد> flutter test tool/nav_flush_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «خليه جزء من التطبيق» — أي ممتدّاً إلى الحافّتين ملتصقاً بالأسفل، لا
// بطاقةً لها هامشٌ من ثلاث جهات.
//
// ── وقرارٌ صغيرٌ يبقى: الحواف ────────────────────────────────────────────────
//
// الملتصقُ بالأسفل لا معنى لاستدارة حافّتيه السفليّتين — تقعان خارج الشاشة.
// **فتبقى العلويّتان مستديرتين أم تُسوّى الأربعُ؟** وهما شكلان مختلفان:
// الأوّلُ يقول «سطحٌ يعلو المحتوى»، والثاني يقول «حافّةُ الشاشة نفسُها».
//
// ── وما تحت الشريط ليس فراغاً ──────────────────────────────────────────────
//
// في جوالات الإيماءة شريطٌ للنظام أسفلَ الشاشة. **والملتصقُ يمتدّ تحته**
// ويُزاح محتواه فوقه بمقدار `MediaQuery.padding.bottom` — ولولا ذلك لَوقعت
// الأيقوناتُ على خطّ النظام. ويُرسم هنا بقدرٍ مفترَضٍ (٣٤) ليُرى أثرُه.
//
// ── وما فيه حقيقيّ ────────────────────────────────────────────────────────
//
// اللقطةُ الأولى `GlassNavBar` المشحونةُ بحرفها. والشكلان بعدها **مُعادا
// البناء** — الالتصاقُ يقتضي إسقاطَ الهامش و`SafeArea` من داخل الودجت، ولا
// سبيلَ إليه بلا تغييرٍ في `lib/`. والقياساتُ والألوانُ منقولةٌ عنها بحرفها.
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

final _items = <GlassNavItem>[
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

/// شريطُ النظام أسفلَ جوالات الإيماءة — يُفترض هنا ليُرى أثرُه.
const double _systemBar = 34;

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

/// لوحٌ ملوّنٌ تحت الشريط ليُرى الزجاجُ زجاجاً، وخطُّ النظام أسفلَه.
Widget _stage(Widget bar) => Container(
      height: 170,
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
          // خطُّ النظام — يُرسم فوق الكلّ ليُرى أين تقع حافّةُ الشاشة.
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 120,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );

/// شريطٌ ملتصقٌ مُعادُ البناء — بلا هامشٍ، ومحتواه مُزاحٌ فوق خطّ النظام.
///
/// **والمقاديرُ تُمرَّر لا تُكتب**: طُلب تصغيرُ الأيقونات ولم يُذكر كم،
/// فتُرسم ثلاثةُ مقاديرَ في صورةٍ واحدةٍ ويُختار منها بالعين. وكلُّ مقدارٍ
/// ثلاثةُ أرقامٍ تتحرّك معاً — أيقونةُ الجار، وقطرُ القرص، وأيقونتُه —
/// ولو صُغّر أحدُها وحدَه لَاختلّت نسبتُه إلى أخويه.
Widget _flush({
  required bool roundedTop,
  double iconSize = 21,
  double discSize = 54,
  double discIcon = 24,
}) {
  const barHeight = GlassNavBar.barHeight;
  const raise = GlassNavBar.raise;
  final radius = roundedTop
      ? const BorderRadius.vertical(top: Radius.circular(24))
      : BorderRadius.zero;

  return SizedBox(
    height: barHeight + raise + _systemBar,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Align(
          alignment: Alignment.bottomCenter,
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: barHeight + _systemBar,
                padding: const EdgeInsets.only(bottom: _systemBar),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      Expanded(
                        child: i == 0
                            ? const SizedBox.shrink()
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_items[i].icon, size: iconSize, color: AppColors.ink2),
                                  const SizedBox(height: 3),
                                  Text(
                                    _items[i].label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      height: 1.2,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.ink2,
                                      fontFamilyFallback: arabicFallback,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          left: 0,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: i == 0
                      ? Center(
                          child: Container(
                            width: discSize,
                            height: discSize,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surface2, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.ink.withValues(alpha: 0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(_items[i].activeIcon,
                                size: discIcon, color: AppColors.accentInk),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('الملتصقُ بأربعة مقادير', (tester) async {
    tester.view.physicalSize = const Size(1180, 1900);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(
      ColoredBox(
        color: AppColors.surface2,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _caption('ملتصقٌ بحافّته — والمقاسُ كما هو اليوم (٢١ · ٥٤ · ٢٤)'),
            _stage(_flush(roundedTop: true)),
            _caption('(١) أصغرُ قليلاً — ١٩ · ٤٨ · ٢١'),
            _stage(_flush(roundedTop: true, iconSize: 19, discSize: 48, discIcon: 21)),
            _caption('(٢) أصغرُ منها — ١٧ · ٤٤ · ١٩'),
            _stage(_flush(roundedTop: true, iconSize: 17, discSize: 44, discIcon: 19)),
            _caption('(٣) أصغرُها — ١٦ · ٤٠ · ١٧'),
            _stage(_flush(roundedTop: true, iconSize: 16, discSize: 40, discIcon: 17)),
            const SizedBox(height: Space.lg),
          ],
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/nav-flush-options.png');
  });
}
