// **مقترحٌ لا تنفيذ.** شاشةُ انطلاقِ التطبيق — شعارٌ نبيذيٌّ متحرّك.
//
//   SHOTS=<مجلّد> flutter test tool/splash_proposal_test.dart
//   ثمّ:  python3 tool/make_gif.py <مجلّد>
//
// يُخرج **إطاراً إطاراً** (`frame_000.png` …) لا لقطةً واحدة، لأنّ المطلوبَ
// حركةٌ لا صورة. و`make_gif.py` يجمعها فيديوَ GIF يُرسَل إلى صاحب المنصّة.
//
// ── ما هو مصوَّرٌ وما هو مرسوم ───────────────────────────────────────────────
//
// **الخليّةُ (اليوم) مصوَّرةٌ من الشيفرة المدفوعة** — `BootScreen` بعينها: ما
// يراه فاتحُ التطبيق اليومَ لحظةَ الانطلاق.
//
// **والخليّتان (أ) و(ب) مرسومتان ويُقال** — غيرُ منفَّذتين بعد. لكنّهما
// مبنيّتان بعناصر التطبيق نفسِها: `BrandBackdrop` و`ArchPainter` وأيقونةُ
// الحزمة `assets/brand/app_mark.png` وألوانُ `AppColors`. ولا صورةَ مأخوذةٌ
// من الشبكة ولا ملفَّ حركةٍ من أحد.
//
// **و«الثلاثيُّ» في (ب) منظورٌ لا مجسَّم.** `Matrix4` بمنظورٍ تدير المستويَ
// فيُرى كأنّه ينقلب في الفضاء — وهي الحيلةُ التي تستعملها التطبيقاتُ كلُّها.
// وأمّا مجسَّمٌ حقيقيٌّ بإضاءةٍ وظلالٍ فيحتاج ملفَّ حركةٍ من مصمّم، وذاك
// خيارٌ ثالثٌ مذكورٌ في الرسالة لا يمكن أن يُرسَم هنا بلا ملفّه.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/welcome.dart';

// ── الخطوط ───────────────────────────────────────────────────────────────────
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
    final image = await boundary.toImage(pixelRatio: 1.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// الأيقونةُ المشحونةُ نفسُها — تُقرأ مرّةً وتُفكّ بزمنٍ حقيقيّ.
late final Uint8List _mark;

double _ease(double t) => Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));

/// ما بين [a] و[b] من الزمن الكلّيّ، مُعاداً إلى ٠…١.
double _span(double t, double a, double b) =>
    ((t - a) / (b - a)).clamp(0.0, 1.0);

// ════════════════════════════════════════════════════════════════════════════
//  (أ) نبضٌ وتوهّج — ثنائيّةُ الأبعاد
// ════════════════════════════════════════════════════════════════════════════
//
//  القوسُ يُرسَم بيدٍ، ثمّ تحطّ الأيقونةُ وتتنفّس، ويمرّ عليها شريطُ ضوءٍ
//  ذهبيّ، والاسمُ يصعد تحتها.
class _OptionA extends StatelessWidget {
  const _OptionA({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final arch = _ease(_span(t, 0.00, 0.55));
    final mark = _ease(_span(t, 0.30, 0.70));
    final name = _ease(_span(t, 0.55, 0.85));
    // نبضٌ بطيءٌ لا يقف — الشاشةُ تبقى حيّةً ما دام الإقلاع.
    final breath = 1 + 0.03 * math.sin(t * math.pi * 2.4);
    // شريطُ الضوء يمرّ مرّةً بعد حطّ الأيقونة.
    final sheen = _span(t, 0.55, 0.95);

    return BrandBackdrop(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: ArchPainter(progress: arch)),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                opacity: mark,
                child: Transform.scale(
                  scale: (0.72 + 0.28 * mark) * breath,
                  child: _Sheen(
                    progress: sheen,
                    child: Image.memory(_mark,
                        width: 108, height: 108,
                        filterQuality: FilterQuality.medium),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Opacity(
                opacity: name,
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - name)),
                  child: const Text(
                    'فرحتي',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: AppColors.goldOnAccent,
                      fontFamilyFallback: arabicFallback,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// شريطُ ضوءٍ يمرّ فوق ما تحته — ويُقصّ عليه فلا يسيل خارجَه.
class _Sheen extends StatelessWidget {
  const _Sheen({required this.progress, required this.child});
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) return child;
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment(-3 + 6 * progress, -1),
        end: Alignment(-2 + 6 * progress, 1),
        colors: [
          Colors.transparent,
          AppColors.goldOnAccent.withValues(alpha: 0.85),
          Colors.transparent,
        ],
        stops: const [0.35, 0.5, 0.65],
      ).createShader(rect),
      child: child,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  (ب) انقلابٌ بمنظور — «ثلاثيُّ الأبعاد»
// ════════════════════════════════════════════════════════════════════════════
//
//  الأيقونةُ تنقلب حول محورها الرأسيّ وتستقرّ، وخلفها حلقةٌ ذهبيّةٌ تدور في
//  مستوىً مائل. والمنظورُ من `Matrix4` لا من مجسَّم.
class _OptionB extends StatelessWidget {
  const _OptionB({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final spin = _ease(_span(t, 0.05, 0.72));
    final name = _ease(_span(t, 0.62, 0.90));
    // دورتان كاملتان ثمّ استقرار.
    final angle = (1 - spin) * math.pi * 2.6;
    final ring = t * math.pi * 2;
    final lift = _ease(_span(t, 0.0, 0.6));

    return BrandBackdrop(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: ArchPainter(progress: _ease(_span(t, 0, 0.5)))),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(200, 200),
                      painter: _OrbitPainter(angle: ring, fade: lift),
                    ),
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        // **والمنظورُ هو كلُّ الحيلة.** بلا هذا السطر تصير
                        // الدورةُ سحقاً أفقيّاً لا انقلاباً في الفضاء.
                        ..setEntry(3, 2, 0.0015)
                        ..rotateY(angle)
                        ..rotateX(0.22 * (1 - spin)),
                      child: Opacity(
                        opacity: lift,
                        child: Image.memory(_mark,
                            width: 116, height: 116,
                            filterQuality: FilterQuality.medium),
                      ),
                    ),
                  ],
                ),
              ),
              Opacity(
                opacity: name,
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - name)),
                  child: const Text(
                    'فرحتي',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: AppColors.goldOnAccent,
                      fontFamilyFallback: arabicFallback,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// حلقةٌ ذهبيّةٌ في مستوىً مائل — يُضيّق ارتفاعُها فتُقرأ دورةً لا دائرة.
class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.angle, required this.fade});
  final double angle;
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final rx = size.width * 0.44;
    final ry = size.height * 0.16;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.35);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.goldOnAccent.withValues(alpha: 0.35 * fade),
    );
    // نقطةٌ تجري على الحلقة — وهي ما يجعل الدورةَ تُرى.
    final p = Offset(rx * math.cos(angle), ry * math.sin(angle));
    canvas.drawCircle(
      p,
      3.2,
      Paint()..color = AppColors.goldOnAccent.withValues(alpha: 0.95 * fade),
    );
    canvas.drawCircle(
      p,
      9,
      Paint()
        ..color = AppColors.goldOnAccent.withValues(alpha: 0.18 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbitPainter old) =>
      old.angle != angle || old.fade != fade;
}

// ── لوحُ العرض ───────────────────────────────────────────────────────────────
class _Board extends StatelessWidget {
  const _Board({required this.t});
  final double t;

  static const double _w = 268;
  static const double _h = 520;

  Widget _cell(String label, String sub, Widget screen) => SizedBox(
        width: _w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 2, right: 2),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 2),
              child: Text(
                sub,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: AppColors.muted,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(width: _w, height: _h, child: screen),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFE9E1DB),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _cell('اليوم — شاشةُ الانطلاق', 'دوّارٌ وسطر. مصوَّرةٌ من الشيفرة المدفوعة.',
                    const BootScreen()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _cell('(أ) نبضٌ وتوهّج', 'ثنائيّةُ الأبعاد — مرسومة',
                    _OptionA(t: t)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _cell('(ب) انقلابٌ بمنظور', '«ثلاثيّةٌ» بالمنظور — مرسومة',
                    _OptionB(t: t)),
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
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(key: const ValueKey('shot'), child: child),
      ),
    );

const _frames = 48;

void main() {
  setUpAll(() async {
    await _loadFonts();
    _mark = File('assets/brand/app_mark.png').readAsBytesSync();
  });

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('الإطارات', (tester) async {
    tester.view.physicalSize = const Size(1740, 1220);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    Directory(out).createSync(recursive: true);

    for (var i = 0; i < _frames; i++) {
      final t = i / (_frames - 1);
      await tester.pumpWidget(_wrap(_Board(t: t)));
      // **والساعةُ تُدفع دفعاً حقيقيّاً لا بصفر.** خليّةُ «اليوم» فيها
      // `LoadingBlock` تُمهل ٢٢٠ جزءاً من الثانية قبل أن تُظهر شيئاً — فبلا
      // دفعِ الساعة تخرج الخليّةُ فارغةً، ويُقرأ اللوحُ كذباً: «لا شيءَ
      // اليوم». وهي بذلك تدور في الفيديو كما تدور في الجهاز.
      await tester.pump(const Duration(milliseconds: 42));
      // **وتُمهَل الأيقونةُ زمناً حقيقيّاً حتى تُفكّ** — `Image.memory` تفكّ
      // الترميزَ في خيطٍ آخر. وبلا هذا يخرج أوّلُ إطارٍ بلا شعار.
      if (i == 0) {
        for (var k = 0; k < 4; k++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 250)));
          await tester.pump(const Duration(milliseconds: 120));
        }
      }
      await _shoot(tester, find.byKey(const ValueKey('shot')),
          '$out/frame_${i.toString().padLeft(3, '0')}.png');
    }

    // **ولا يُصدَّق أنّ الشعارَ رُسم: تُسأل الشجرة.**
    expect(find.byType(BootScreen), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('فرحتي'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
