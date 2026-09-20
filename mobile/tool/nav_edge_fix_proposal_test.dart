// **عطبٌ ومُقترَحُ إصلاحه.** الحفرةُ تنكسر في التبويب الأوّل والأخير.
//
//   SHOTS=<مجلّد> flutter test tool/nav_edge_fix_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما شكا منه ─────────────────────────────────────────────────────────────
//
// «هذا لم يتنفّذ في تطبيق، أو أنّه ليس واضحاً للعميل ومقدّم الخدمة» — ومعها
// لقطتان: القرصُ في طرف الشريط ولا حفرةَ حولَه تُرى، وفي إحداهما يتدلّى
// نصفُه خارجَ الشريط.
//
// ── ونُفّذ، لكنّه ينكسر في الطرفين ────────────────────────────────────────
//
// مركزُ الخانة الأولى نحوُ ‎٣٦‎ بكسلاً من حافّة الشريط، ونصفُ قطر الحفرة ‎٢٩‎،
// واستدارةُ الركن ‎٢٤‎. فالحفرةُ تقع على الركن المستدير، ويأكل القطعُ
// المشترَك (`PathOperation.intersect`) نصفَها — فلا تتشكّل، ويتدلّى القرصُ
// خارج الشريط.
//
// **وفي التبويبات الوسطى يتشكّل الشكلُ تماماً** — وذلك يُرى في اللوح الثاني،
// وهو الدليلُ على أنّه نُفّذ.
//
// ── ولم يكشفه اختبارٌ ─────────────────────────────────────────────────────
//
// الحزمةُ تجسّ المسارَ عند مركز القرص وتسأل «أمقصوصٌ هنا؟» — وهو مقصوصٌ في
// الطرف أيضاً، بل أكثرُ ممّا يجب. **فالسؤالُ كان ناقصاً لا الجوابَ خاطئاً**:
// يجب أن يُسأل أيضاً أيقع القرصُ كلُّه داخلَ عرض الشريط.
//
// ── وما فيه حقيقيٌّ وما هو مرسوم ──────────────────────────────────────────
//
// اللوحان الأوّلان `GlassNavBar` المشحونةُ نفسُها — **وهما العطبُ كما هو
// اليوم**. والمقترحاتُ تحتهما مُعادةُ البناء بشيفرة القصّ نفسِها ومعها
// الإصلاح، لأنّ الشريطَ لا يُزاح من خارجه.
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

final _items = <GlassNavItem>[
  GlassNavItem(label: tr('الرئيسية'), icon: Icons.home_outlined, activeIcon: Icons.home),
  GlassNavItem(
    label: tr('حجوزاتي'),
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long,
  ),
  GlassNavItem(label: tr('استكشف'), icon: Icons.search, activeIcon: Icons.search),
  GlassNavItem(
    label: tr('خطة العرس'),
    icon: Icons.fact_check_outlined,
    activeIcon: Icons.fact_check,
  ),
  GlassNavItem(label: tr('حسابي'), icon: Icons.person_outline, activeIcon: Icons.person),
];

const double _screen = 390;
const double _discR = GlassNavBar.discSize / 2;
const double _notchR = _discR + GlassNavBar.notchGap;
const double _top = GlassNavBar.raise;

/// نسخةُ القاطع ومعه الإصلاح — بشيفرة الكِت نفسِها.
class _Clip extends CustomClipper<Path> {
  const _Clip({required this.cx, required this.corner});
  final double cx;
  final double corner;

  Path build(Size size) {
    final host = Rect.fromLTWH(0, _top, size.width, size.height - _top);
    final rounded = Path()
      ..addRRect(RRect.fromRectAndRadius(host, Radius.circular(corner)));
    final guest = Rect.fromCircle(center: Offset(cx, _top), radius: _notchR);
    final notched = const CircularNotchedRectangle().getOuterPath(host, guest);
    return Path.combine(PathOperation.intersect, rounded, notched);
  }

  @override
  Path getClip(Size size) => build(size);
  @override
  bool shouldReclip(_Clip old) => old.cx != cx || old.corner != corner;
}

class _Outline extends CustomPainter {
  const _Outline(this.clipper);
  final _Clip clipper;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      clipper.build(size),
      Paint()
        ..color = AppColors.ink.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_Outline old) => true;
}

Widget _disc(IconData icon) => Container(
      width: _discR * 2,
      height: _discR * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: 20, color: AppColors.accentInk),
    );

Widget _cellOf(GlassNavItem item) => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(item.icon, size: GlassNavBar.iconSize, color: AppColors.ink2),
        const SizedBox(height: 3),
        Text(
          item.label,
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
    );

/// شريطٌ مُعادُ البناء ومعه الإصلاح المقترَح.
///
/// * `inset` — حشوٌ من طرفَي الشريط يُزيح البنودَ كلَّها إلى الداخل.
/// * `clamp` — تُحبس الحفرةُ والقرصُ معاً داخلَ حدٍّ يسع الحفرةَ كاملة.
/// * `corner` — استدارةُ الأركان.
Widget _fixed({
  required int index,
  double inset = 0,
  bool clamp = true,
  double corner = GlassNavBar.corner,
}) {
  const side = GlassNavBar.sideMargin;
  final width = _screen - side * 2;
  final usable = width - inset * 2;
  final cell = usable / _items.length;
  final raw = width - inset - (index + 0.5) * cell; // RTL
  final limit = corner + _notchR;
  final cx = clamp ? raw.clamp(limit, width - limit) : raw;
  final clipper = _Clip(cx: cx, corner: corner);

  return SizedBox(
    width: _screen,
    height: _top + GlassNavBar.barHeight,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: side),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          ClipPath(
            clipper: clipper,
            child: Padding(
              padding: const EdgeInsets.only(top: _top),
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.86),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: inset),
                  child: Row(
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        Expanded(
                          child: i == index
                              ? const SizedBox.shrink()
                              : _cellOf(_items[i]),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(child: CustomPaint(painter: _Outline(clipper))),
          Positioned(left: cx - _discR, top: 0, child: _disc(_items[index].activeIcon)),
        ],
      ),
    ),
  );
}

Widget _real(int index) => SizedBox(
      width: _screen,
      height: _top + GlassNavBar.barHeight + GlassNavBar.bottomGap,
      child: GlassNavBar(index: index, onSelect: (_) {}, items: _items),
    );

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
          Center(
            child: SizedBox(
              width: _screen,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Container(
                      height: 78,
                      margin: const EdgeInsets.symmetric(horizontal: Space.lg),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  bar,
                ],
              ),
            ),
          ),
        ],
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('اللوح', (tester) async {
    tester.view.physicalSize = const Size(900, 2700);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(ListView(
      padding: const EdgeInsets.symmetric(vertical: Space.lg),
      children: [
        _panel(
          '١ — العطب:',
          'التبويبُ الأخير («حسابي»)',
          'القرصُ على الركن المستدير، فالحفرةُ لا تتشكّل ويتدلّى نصفُه خارجَ الشريط',
          _real(4),
        ),
        _panel(
          '٢ — وهو منفَّذ:',
          'التبويبُ الأوسط («استكشف»)',
          'الشريطُ نفسُه في تبويبٍ وسط — الحفرةُ تامّةٌ كما أردتَها',
          _real(2),
        ),
        _panel(
          '(أ)',
          'تُزاح الحفرةُ والقرصُ إلى الداخل',
          'أقلُّ تغيير — والقرصُ في الطرفين ينزاح قليلاً عن مركز خانته',
          _fixed(index: 4),
        ),
        _panel(
          '(ب)',
          'مع تصغير استدارة الأركان',
          'إزاحةٌ أقلّ، وأركانٌ أقلُّ استدارةً من لقطتك',
          _fixed(index: 4, corner: 14),
        ),
        _panel(
          '(ج)',
          'حشوٌ من طرفَي الشريط مع الإزاحة',
          'البنودُ كلُّها تنزاح إلى الداخل بالتساوي، فيبقى القرصُ فوق خانته — والخاناتُ تضيق قليلاً',
          _fixed(index: 4, inset: 12),
        ),
        _panel(
          '',
          'و(ج) في التبويب الأوّل',
          'ليُرى أنّ الطرفين سواء',
          _fixed(index: 0, inset: 12),
        ),
      ],
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull, reason: 'فاض اللوحُ عن الشاشة');
    expect(find.byType(GlassNavBar), findsNWidgets(2));
    expect(find.byType(ClipPath), findsNWidgets(6));

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/nav-edge-fix.png');
  });
}
