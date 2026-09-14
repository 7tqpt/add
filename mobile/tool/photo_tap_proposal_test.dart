// **مقترحٌ لا تنفيذ.** «صور شخصية وغلاف خليهم قابل للضغط وليس متحجر» —
// يُعرض قبل أن يُلمَس `lib/`.
//
//   SHOTS=<مجلّد> COVER=<صورة> flutter test tool/photo_tap_proposal_test.dart
//
// ── ولماذا يُسأل قبل أن يُنفَّذ ───────────────────────────────────────────────
//
// «قابل للضغط» له قراءتان تؤدّيان إلى شيئين مختلفين تماماً:
//
//   · **يُضغط فيُعرض**: تكبر الصورةُ ملءَ الشاشة كما في فيسبوك.
//   · **يُضغط فيُبدَّل**: تُفتح ورقةُ الكاميرا والمعرض.
//
// وحالُ التطبيق اليوم متفرّقة، وهذا نصفُ العلّة:
//
//   · غلافُ «حسابي» وغلافُ ملفّ المزوّد — **يُضغطان فيُبدَّلان** (منذ
//     الدمجة الأخيرة، في حزمة `build-102`).
//   · قرصُ الصورة في ملفّ المزوّد وفي «تعديل بياناتي» — **يُضغط فيُبدَّل**.
//   · **وقرصُ الصورة في «حسابي» لا يُضغط أصلاً** — وهو المتحجّر.
//   · وفي صفحة المزوّد العامّة لا يُضغط شيء — وهناك لا تبديلَ أصلاً، فالضغطُ
//     لا يعني إلّا العرض.
//
// ── والمرسومُ هنا مرسومٌ ويُقال ──────────────────────────────────────────────
//
// الخليّتان (أ) و(ب) **ليستا مصوَّرتين من الشيفرة**: ما فيهما غيرُ منفَّذٍ
// بعد. لكنّهما بُنيتا بعناصر التطبيق نفسِها وثيمته (`buildTheme()`،
// `ListTile`، `AppColors`) — لا صناديقَ مرسومةً بالألوان.
//
// **وصورةُ الغلاف مركَّبةٌ بخوارزميّة** (`make_sample_cover.py`) لا مأخوذةٌ
// من الشبكة.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/theme.dart';

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
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

late final Uint8List _cover;

// ── لوحُ العرض ───────────────────────────────────────────────────────────────
class _Sheet extends StatelessWidget {
  const _Sheet({required this.cells});
  final List<({String label, Widget screen})> cells;

  static const double _w = 392;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFE9E1DB),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < cells.length; i++)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, right: 2),
                        child: Text(
                          cells[i].label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            fontFamilyFallback: arabicFallback,
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          key: ValueKey('cell$i'),
                          width: _w,
                          height: 700,
                          child: cells[i].screen,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
}

Widget _wrap(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 44)),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(key: const ValueKey('shot'), child: child),
        ),
      ),
    );

/// خلفيّةٌ باهتةٌ تُشبه الشاشةَ تحت الورقة — كي تُقرأ الورقةُ ورقةً.
Widget _dimmed(Widget child) => Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AppColors.page),
        Positioned(
          top: 0,
          right: 0,
          left: 0,
          height: 196,
          child: Image.memory(_cover, fit: BoxFit.cover),
        ),
        Container(color: Colors.black.withValues(alpha: 0.45)),
        Align(alignment: Alignment.bottomCenter, child: child),
      ],
    );

/// (أ) ورقةٌ بثلاثة خيارات — عرضٌ ثمّ تبديل.
class _OptionA extends StatelessWidget {
  const _OptionA();

  @override
  Widget build(BuildContext context) => _dimmed(
        Material(
          color: AppColors.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: Space.sm),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: Space.sm),
                ListTile(
                  leading: const Icon(Icons.zoom_out_map_rounded,
                      color: AppColors.accent),
                  title: Text(tr('عرض الصورة')),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined,
                      color: AppColors.accent),
                  title: Text(tr('التقاط صورة')),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined,
                      color: AppColors.accent),
                  title: Text(tr('اختيار من المعرض')),
                  onTap: () {},
                ),
                const SizedBox(height: Space.sm),
              ],
            ),
          ),
        ),
      );
}

/// (ب) الصورةُ ملءَ الشاشة، وفيها بابٌ إلى التبديل.
class _OptionB extends StatelessWidget {
  const _OptionB();

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          Center(child: Image.memory(_cover, fit: BoxFit.contain)),
          Positioned(
            top: 44 + Space.sm,
            right: Space.sm,
            left: Space.sm,
            child: Row(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.photo_camera_outlined,
                      size: 18, color: Colors.white),
                  label: Text(
                    tr('تغيير'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontFamilyFallback: arabicFallback,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    final path = Platform.environment['COVER'] ?? '';
    if (path.isEmpty || !File(path).existsSync()) {
      throw StateError('COVER=<صورة> لازمة');
    }
    _cover = File(path).readAsBytesSync();
  });

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('اللوح', (tester) async {
    tester.view.physicalSize = const Size(2700, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_Sheet(cells: const [
      (label: '(أ) ورقةٌ فيها العرضُ والتبديل — مرسومة', screen: _OptionA()),
      (label: '(ب) الصورةُ ملءَ الشاشة — مرسومة', screen: _OptionB()),
    ])));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _settleImages(tester);

    expect(find.text('عرض الصورة'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/photo-tap.png');
  });
}
