// **مقترحٌ لا تنفيذ.** قوسٌ تحت القرص في الشريط السفليّ.
//
//   SHOTS=<مجلّد> flutter test tool/nav_notch_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «أريد في الشريط السفليّ خطّاً أسودَ خفيفاً يفصل بين أيقونة وشريط» — فعُرضت
// عليه خطوطٌ مستقيمة، فقال «لا، شُف صورة» ورسم بيده **قوساً تحت القرص**:
// يبدأ من أعلى يمينه، ينزل تحته، ويصعد إلى أعلى يساره.
//
// فالمرادُ ليس حافّةَ الشريط كلَّها — بل الحدُّ بين القرص وما تحته.
//
// ── وما فيه حقيقيٌّ وما هو مرسوم ──────────────────────────────────────────
//
// **حقيقيّ:** `GlassNavBar` المشحونةُ نفسُها ببنود العميل الخمسة — بزجاجها
// وتمويهها وقرصها وظلّها.
//
// **ومرسومٌ يُقال:** القوسُ مُركَّبٌ **فوقها** في كومةٍ لا مكتوبٌ فيها؛
// وموضعُه محسوبٌ بثوابتها هي (`raise` وعرضُ الخانة وقطرُ القرص).
//
// **و(ج) أبعدُ من ذلك — قصُّ الزجاج مُحاكًى لا حقيقيّ:** الشريطُ لا يُقصّ من
// خارجه، فالمرسومُ هناك لونُ الصفحة فوق الزجاج ليُرى شكلُ القصّ. وأمّا في
// التنفيذ فيُقصّ الزجاجُ فعلاً ويُرى ما تحته من خلاله.
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

/// بنودُ العميل — وهي التي في لقطته.
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
  GlassNavItem(
    label: tr('حسابي'),
    icon: Icons.person_outline,
    activeIcon: Icons.person,
  ),
];

const _selected = 2;
const double _w = 390;
const double _cell = _w / 5;
const double _stage = GlassNavBar.barHeight + GlassNavBar.raise;

/// مركزُ القرص من اليسار — الخانةُ في RTL تُعدّ من اليمين.
const double _cx = _w - (_selected + 0.5) * _cell;

/// نصفُ عرض القوس — أوسعُ من القرص قليلاً كما في رسمته.
const double _reach = 48;

/// كم ينزل القوسُ تحت حافّة الشريط.
const double _dip = 22;

/// القوسُ وحدَه — خطٌّ يُرسم ولا يُقصّ شيء.
class _ArcOnly extends CustomPainter {
  _ArcOnly({required this.color, required this.stroke, this.fullEdge = false});
  final Color color;
  final double stroke;

  /// هل يمتدّ خطٌّ مستقيمٌ على بقيّة الحافّة؟
  final bool fullEdge;

  @override
  void paint(Canvas canvas, Size size) {
    const top = GlassNavBar.raise;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final arc = Path()
      ..moveTo(_cx - _reach, top - 4)
      // نقطةُ التحكّم ضعفُ الغوص: المنحنى التربيعيُّ يبلغ نصفَ المسافة إليها.
      ..quadraticBezierTo(_cx, top + _dip * 2, _cx + _reach, top - 4);
    canvas.drawPath(arc, p);

    if (fullEdge) {
      final edge = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke;
      canvas.drawLine(Offset(0, top), Offset(_cx - _reach, top - 4), edge);
      canvas.drawLine(Offset(_cx + _reach, top - 4), Offset(size.width, top), edge);
    }
  }

  @override
  bool shouldRepaint(_ArcOnly old) => true;
}

/// **مُحاكاةُ القصّ**: لونُ الصفحة يُطلى فوق الزجاج ليُرى شكلُ التقعير.
/// وفي التنفيذ يُقصّ الزجاجُ فعلاً فيُرى ما تحته من خلاله.
class _NotchMock extends CustomPainter {
  _NotchMock({required this.line});
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    const top = GlassNavBar.raise;
    final scoop = Path()
      ..moveTo(_cx - _reach, top)
      ..quadraticBezierTo(_cx, top + _dip * 2, _cx + _reach, top)
      ..close();
    canvas.drawPath(scoop, Paint()..color = AppColors.surface2);
    canvas.drawPath(
      scoop,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_NotchMock old) => true;
}

/// نسخةُ القرص — **مرسومةٌ** بقياس `_GlassNavDisc` ولونِه ومقاسِ أيقونته.
///
/// ولا تُستعمل إلّا في (ج): محاكاةُ القصّ تُطلى فوق الشريط كلِّه فتبتلع قرصَه،
/// فيُعاد فوقها. وفي التنفيذ لا يُعاد شيء — الزجاجُ يُقصّ تحته وهو في مكانه.
Widget _discCopy() => Container(
      width: 44,
      height: 44,
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
      child: Icon(_items[_selected].activeIcon, size: 19, color: AppColors.accentInk),
    );

Widget _bar({CustomPainter? over, bool redrawDisc = false}) => SizedBox(
      width: _w,
      height: _stage,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          GlassNavBar(index: _selected, onSelect: (_) {}, items: _items),
          if (over != null) IgnorePointer(child: CustomPaint(painter: over)),
          if (redrawDisc)
            Positioned(top: 0, left: _cx - 22, child: IgnorePointer(child: _discCopy())),
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
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final ink = AppColors.ink.withValues(alpha: 0.28);

    await tester.pumpWidget(_wrap(ListView(
      padding: const EdgeInsets.symmetric(vertical: Space.lg),
      children: [
        _panel('اليوم:', 'بلا قوس', 'القرصُ يقف على الشريط بلا حدٍّ بينهما',
            _bar()),

        _panel(
          '(أ)',
          'القوسُ وحدَه تحت القرص',
          'كما رسمتَه بيدك — حدٌّ بين القرص وما تحته، والحافّةُ باقيةٌ كما هي',
          _bar(over: _ArcOnly(color: ink, stroke: 2.0)),
        ),

        _panel(
          '(ب)',
          'القوسُ ويمتدّ خطٌّ على بقيّة الحافّة',
          'فيصير حدّاً للشريط كلِّه لا للقرص وحدَه',
          _bar(over: _ArcOnly(color: ink, stroke: 1.6, fullEdge: true)),
        ),

        _panel(
          '(ج)',
          'الزجاجُ يُقعَّر — القرصُ يجلس في حفرته',
          'أقواها شكلاً وأثقلُها عملاً. **والقصُّ هنا محاكًى بلون الصفحة، '
              'والقرصُ فوقه مُعادُ الرسم**؛ وفي التنفيذ يُقصّ الزجاجُ فعلاً '
              'فيُرى ما تحته من خلاله',
          _bar(over: _NotchMock(line: ink), redrawDisc: true),
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
          ('١ — خفيفٌ (١٨٪ وسُمكٌ ١٫٥)', 0.18, 1.5),
          ('٢ — متوسّط (٢٨٪ وسُمكٌ ٢)', 0.28, 2.0),
          ('٣ — ظاهرٌ كرسمتك (٤٥٪ وسُمكٌ ٢٫٦)', 0.45, 2.6),
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
                  child: _bar(
                    over: _ArcOnly(
                      color: AppColors.ink.withValues(alpha: step.$2),
                      stroke: step.$3,
                    ),
                  ),
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
    // الأشرطةُ السبعةُ كلُّها حقيقيّة — فلو سقط أحدُها لَخرجت اللوحةُ ناقصةً.
    expect(find.byType(GlassNavBar), findsNWidgets(7));

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/nav-notch.png');
  });
}
