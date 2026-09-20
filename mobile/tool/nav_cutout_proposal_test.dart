// **مقترحٌ لا تنفيذ.** الشريطُ السفليُّ بحفرةٍ دائريّةٍ يجلس فيها القرص.
//
//   SHOTS=<مجلّد> flutter test tool/nav_cutout_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// عُرضت عليه خطوطٌ وأقواسٌ فقال «ولا واحد»، وأرسل لقطةَ شريطٍ أزرقَ فيه
// **حفرةٌ دائريّةٌ محفورةٌ في الشريط نفسِه** يجلس فيها القرص، وقال: «أريد
// نفس الاستايل بدون تغيير الألوان».
//
// فالمرادُ الشكلُ لا اللون: الحفرةُ تُقطع من حافّة الشريط، وبينها وبين القرص
// فرجةٌ يُرى منها ما تحت الشريط — فيبدو القرصُ جالساً فيها لا واقفاً عليها.
//
// ── وثلاثةُ أشياءَ في لقطته لا شيءٌ واحد ──────────────────────────────────
//
//   ١. الحفرةُ الدائريّة.
//   ٢. وشريطٌ **عائمٌ** له هامشٌ من الجوانب وأركانُه الأربعةُ مستديرة —
//      وشريطُنا اليومَ ملتصقٌ بالحافّة بطلبه هو («خليه جزء من التطبيق»).
//   ٣. **وبلا أسماءَ تحت الأيقونات** — وشريطُنا فيه الأسماء.
//
// فتُعرض مفرَّقةً ليختار: الحفرةَ وحدَها، أو الطرازَ كاملاً، أو بينهما.
//
// ── وهذه الأشرطةُ **مُعادةُ البناء** — يُقال ولا يُدَّعى ─────────────────
//
// `GlassNavBar` لا تُقصّ من خارجها: القصُّ يقع داخلَها على زجاجها. فهذه
// أشرطةٌ بُنيت هنا بشيفرة القصّ التي ستُكتب فيها — **بألوان التطبيق وزجاجه
// وتمويهه وثوابته وأيقوناته بحرفها**، لا صناديقَ ملوّنةٌ تشبهها. وأوّلُ
// لوحٍ وحدَه هو `GlassNavBar` الحقيقيّةُ للمقارنة.
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
  GlassNavItem(label: tr('بحث'), icon: Icons.search, activeIcon: Icons.search),
  GlassNavItem(
    label: tr('خطة العرس'),
    icon: Icons.fact_check_outlined,
    activeIcon: Icons.fact_check,
  ),
  GlassNavItem(label: tr('حسابي'), icon: Icons.person_outline, activeIcon: Icons.person),
];

const _selected = 2;
const double _w = 390;

/// نصفُ قطر القرص — هو `_GlassNavDisc.size / 2` بحرفه.
const double _discR = 22;

/// الفرجةُ بين القرص وحافّة الحفرة — هي التي تُري ما تحت الشريط فيبدو جالساً.
const double _gap = 7;

/// ارتفاعُ الشريط — `GlassNavBar.barHeight` بحرفه.
const double _barH = GlassNavBar.barHeight;

/// مركزُ القرص على حافّة الشريط: نصفُه فوقها ونصفُه في الحفرة.
const double _top = _discR;

/// الحفرةُ تُقطع بـ`CircularNotchedRectangle` — وهي التي تقصّ بها فلاتر
/// `BottomAppBar` حول زرّها العائم. فالشكلُ معياريٌّ لا مُخترَع.
class _NotchClipper extends CustomClipper<Path> {
  _NotchClipper({required this.cx, required this.flush});
  final double cx;

  /// ملتصقٌ بحافّتَي الشاشة (العلويّتان مستديرتان) أم عائمٌ (الأربعُ)؟
  final bool flush;

  Path build(Size size) {
    final host = Rect.fromLTWH(0, _top, size.width, size.height - _top);
    final rounded = Path()
      ..addRRect(RRect.fromRectAndCorners(
        host,
        topLeft: const Radius.circular(24),
        topRight: const Radius.circular(24),
        bottomLeft: Radius.circular(flush ? 0 : 24),
        bottomRight: Radius.circular(flush ? 0 : 24),
      ));
    final guest = Rect.fromCircle(center: Offset(cx, _top), radius: _discR + _gap);
    final notched = const CircularNotchedRectangle().getOuterPath(host, guest);
    return Path.combine(PathOperation.intersect, rounded, notched);
  }

  @override
  Path getClip(Size size) => build(size);

  @override
  bool shouldReclip(_NotchClipper old) => old.cx != cx || old.flush != flush;
}

/// ظلُّ الشريط — يُرسم على شكل الحفرة نفسِه، فلا يخرج مستقيماً من تحتها.
class _NotchShadow extends CustomPainter {
  _NotchShadow(this.clipper);
  final _NotchClipper clipper;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      clipper.build(size).shift(const Offset(0, -2)),
      Paint()
        ..color = AppColors.ink.withValues(alpha: 0.10)
        ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(_NotchShadow old) => true;
}

/// خطٌّ رفيعٌ يحدّ الشريطَ وحفرتَه.
///
/// **وهو لازمٌ لا زينة**: شريطُ لقطته أزرقُ داكنٌ على أبيض، فالحفرةُ تُرى
/// بنفسها. وشريطُنا زجاجٌ فاتحٌ على صفحةٍ فاتحة — فبلا خطٍّ لا يكاد يُرى
/// أين انقطع الزجاجُ وأين بدأت الصفحة. **وهو الخطُّ الذي طلبتَه أوّلاً.**
class _NotchOutline extends CustomPainter {
  _NotchOutline(this.clipper);
  final _NotchClipper clipper;

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
  bool shouldRepaint(_NotchOutline old) => true;
}

/// القرصُ — بقياس `_GlassNavDisc` ولونِه ومقاسِ أيقونته بحرفها.
///
/// **وبلا طوقٍ أبيض**: الطوقُ كان يفصله عن الزجاج حين كان يقف عليه، والحفرةُ
/// تفصله الآن بفرجةٍ حقيقيّة — فطوقٌ فوق فرجةٍ حدّان لشيءٍ واحد.
Widget _disc() => Container(
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
      child: Icon(_items[_selected].activeIcon, size: 20, color: AppColors.accentInk),
    );

Widget _cell(GlassNavItem item, {required bool labels}) => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(item.icon,
            size: labels ? GlassNavBar.iconSize : 21, color: AppColors.ink2),
        if (labels) ...[
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
      ],
    );

/// الشريطُ المقترَح — **مُعادُ البناء** بشيفرة القصّ التي ستُكتب في الكِت.
Widget _notchBar({
  required bool flush,
  required bool labels,
  bool outline = true,
}) {
  final side = flush ? 0.0 : Space.lg;
  final inner = _w - side * 2;
  final cell = inner / _items.length;
  // الخانةُ في RTL تُعدّ من اليمين.
  final cx = inner - (_selected + 0.5) * cell;
  final clipper = _NotchClipper(cx: cx, flush: flush);

  return SizedBox(
    width: _w,
    height: _top + _barH,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: side),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _NotchShadow(clipper)),
          ClipPath(
            clipper: clipper,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Padding(
                padding: const EdgeInsets.only(top: _top),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.72),
                  child: Row(
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        Expanded(
                          child: i == _selected
                              ? const SizedBox.shrink()
                              : _cell(_items[i], labels: labels),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (outline) CustomPaint(painter: _NotchOutline(clipper)),
          Positioned(left: cx - _discR, top: 0, child: _disc()),
        ],
      ),
    ),
  );
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
          // أرضيّةٌ فيها صورةٌ ولونٌ ليُرى ما يمرّ في الفرجة وتحت الزجاج.
          Center(
            child: SizedBox(
              width: _w,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // **لوحٌ داكنٌ يمرّ تحت الشريط ولا نصَّ فيه**: الحفرةُ
                  // تُرى بما يظهر منها، فإن كان تحتها بياضٌ لم يُرَ شيء —
                  // وإن كان نصٌّ خرج مقطوعاً يشغل العين عن الشكل.
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
    tester.view.physicalSize = const Size(900, 2500);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(ListView(
      padding: const EdgeInsets.symmetric(vertical: Space.lg),
      children: [
        _panel(
          'اليوم:',
          'القرصُ يقف على الشريط',
          'وهذا هو `GlassNavBar` الحقيقيّةُ — وما تحتها مُعادُ البناء',
          SizedBox(
            width: _w,
            height: GlassNavBar.barHeight + GlassNavBar.raise,
            child: GlassNavBar(index: _selected, onSelect: (_) {}, items: _items),
          ),
        ),

        _panel(
          '(أ)',
          'الحفرةُ وحدَها',
          'الشريطُ ملتصقٌ بالحافّة والأسماءُ باقية — يتغيّر شكلُ الحافّة لا غير',
          _notchBar(flush: true, labels: true),
        ),

        _panel(
          '(ب)',
          'الطرازُ كاملاً كلقطتك',
          'شريطٌ عائمٌ بهامشٍ من الجوانب، أركانُه الأربعةُ مستديرة، وبلا أسماء',
          _notchBar(flush: false, labels: false),
        ),

        _panel(
          '(ج)',
          'عائمٌ ولكنْ بالأسماء',
          'شكلُ لقطتك، والأسماءُ تبقى لمن لا يعرف الأيقونة',
          _notchBar(flush: false, labels: true),
        ),

        _panel(
          'ولماذا الخطّ؟',
          'هو نفسُه (ب) بلا خطٍّ يحدّه',
          'شريطُ لقطتك أزرقُ داكنٌ فالحفرةُ تُرى بنفسها؛ وزجاجُنا فاتحٌ على '
              'صفحةٍ فاتحة — فبلا خطٍّ لا يكاد يُعرف أين انقطع',
          _notchBar(flush: false, labels: false, outline: false),
        ),
      ],
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull, reason: 'فاض اللوحُ عن الشاشة');
    // لوحٌ حقيقيٌّ واحدٌ وثلاثةٌ مقترحة — فلو سقط أحدُها لَخرجت اللوحةُ ناقصة.
    expect(find.byType(GlassNavBar), findsOneWidget);
    expect(find.byType(ClipPath), findsNWidgets(4));

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/nav-cutout.png');
  });
}
