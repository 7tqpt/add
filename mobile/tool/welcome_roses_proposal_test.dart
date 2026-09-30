// **مقترحُ الترحيب بالورد** — كتصميم صاحب المنصّة، قبل أن يُلمس `lib/`.
//
//   ROSES=<صورة> SHOTS=<مجلّد> flutter test tool/welcome_roses_proposal_test.dart
//
// **الأولى الشاشةُ الحقيقيّة اليوم** (`WelcomeScreen`). **والثانيةُ مركّبةٌ
// في الراسم من قطع التطبيق نفسِها**: `BrandBackdrop` و`ArchMark` — القوسُ
// والقلبُ والاسمُ وحركتُها — والزرّان. والجديدُ فيها شيئان:
//
// - **شريطُ الورد والمخمل مقصوصٌ من صورة صاحب المنصّة نفسِها** (عرضُه
//   ‎٨٧١‎ بكسلاً)، يذوب أعلاه في الأرضيّة فلا يُرى له حدّ.
// - **و«دخول» بتدرّجٍ ذهبيّ** كما في صورته، لا ذهباً مصمتاً.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/welcome.dart';

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
  await initializeDateFormatting('ar');
}

/// شريطُ الورد: يذوب أعلاه وأسفلُه في الأرضيّة بألفاه لا بلونٍ فوقه — فلا
/// يُرى له حدٌّ ولا خيطُ لون. (وقد خرج خيطٌ كهذا في ملخّص «حجوزاتي» حين
/// كان التلاشي لوناً مصمتاً على تدرّج.)
class _Roses extends StatelessWidget {
  const _Roses(this.bytes);
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
          stops: [0, 0.38, 0.82, 1],
        ).createShader(r),
        child: Image.memory(bytes, fit: BoxFit.fitWidth, width: double.infinity),
      );
}

/// «دخول» بتدرّجٍ ذهبيّ — والحبرُ نبيذيٌّ كما هو اليوم.
class _GoldButton extends StatelessWidget {
  const _GoldButton(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6D68A), AppColors.goldOnAccent, Color(0xFFD9A94E)],
          ),
        ),
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.accentDeep,
              ),
            ),
          ),
        ),
      );
}

/// **الزخرفة**: شبكةُ دوائرَ متداخلةٍ بخطٍّ ذهبيٍّ باهت — نقشٌ تقليديٌّ لا
/// صورة — **وتذوب نحو الوسط** فلا تزاحم القوسَ والاسم، وتبقى على الأطراف
/// كما في صورته.
class _PatternPainter extends CustomPainter {
  const _PatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = AppColors.goldOnAccent.withValues(alpha: 0.10);
    const step = 34.0;
    for (var y = -step; y < size.height + step; y += step) {
      final odd = ((y / step).round()).isOdd;
      for (var x = -step; x < size.width + step; x += step) {
        canvas.drawCircle(Offset(x + (odd ? step / 2 : 0), y), step * 0.62, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => false;
}

class _Pattern extends StatelessWidget {
  const _Pattern();

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.95,
          colors: [Colors.transparent, Colors.transparent, Colors.black],
          stops: [0, 0.5, 1],
        ).createShader(r),
        child: const CustomPaint(painter: _PatternPainter(), size: Size.infinite),
      );
}

/// **البريق**: نجومٌ رباعيّةٌ في مواضعها من صورته لا نقاطٌ صاعدة — وفي
/// الشاشة تومض في مكانها. (وهذه لقطةٌ ساكنة، فهي هنا في أشدّ ضيائها.)
class _StarsPainter extends CustomPainter {
  const _StarsPainter();

  // (x, y, حجم) كسورٌ من المساحة — منقولةٌ من مواضعها في صورته.
  static const stars = [
    (0.87, 0.10, 9.0), (0.11, 0.17, 7.0), (0.68, 0.18, 5.0), (0.20, 0.27, 6.0),
    (0.77, 0.33, 4.0), (0.23, 0.39, 4.5), (0.81, 0.45, 6.0), (0.21, 0.53, 5.0),
    (0.86, 0.48, 3.5), (0.12, 0.60, 3.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (fx, fy, r) in stars) {
      final c = Offset(fx * size.width, fy * size.height);
      // هالةٌ ليّنة خلف النجمة.
      canvas.drawCircle(
        c,
        r * 1.8,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFE7A8).withValues(alpha: 0.45),
            const Color(0x00FFE7A8),
          ]).createShader(Rect.fromCircle(center: c, radius: r * 1.8)),
      );
      // نجمةٌ رباعيّةٌ بأضلاعٍ مقعّرة.
      final path = Path()..moveTo(c.dx, c.dy - r);
      for (var k = 1; k <= 4; k++) {
        final a = -math.pi / 2 + k * math.pi / 2;
        path.quadraticBezierTo(c.dx, c.dy, c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      }
      canvas.drawPath(path, Paint()..color = const Color(0xFFFFE7A8));
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => false;
}

class _Proposal extends StatelessWidget {
  const _Proposal(this.roses, {this.ornate = false});
  final Uint8List roses;

  /// الزخرفةُ والنجومُ بدل الذرّات الصاعدة.
  final bool ornate;

  @override
  Widget build(BuildContext context) {
    Widget arch = const ArchMark(t: AlwaysStoppedAnimation(1.0));
    // **والذرّاتُ تُطفأ بطريق التطبيق نفسِه لا بحيلة**: `ArchMark` لا
    // يرسمها حين يُطلب تقليلُ الحركة. فتخرج اللقطةُ بلا نقاطٍ لتُرى النجومُ
    // مكانَها.
    if (ornate) {
      arch = MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: arch,
      );
    }
    return Scaffold(
        body: BrandBackdrop(
          child: Stack(
            children: [
              if (ornate) const Positioned.fill(child: _Pattern()),
              if (ornate)
                const Positioned.fill(
                  child: CustomPaint(painter: _StarsPainter()),
                ),
              Padding(
                padding: const EdgeInsets.all(Space.xl),
                child: Column(
                  children: [
                    const Spacer(),
                    Expanded(flex: 6, child: arch),
                    const Spacer(),
                    const _GoldButton('دخول'),
                    const SizedBox(height: Space.md),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.goldOnAccent,
                        side: const BorderSide(color: AppColors.goldOnAccent),
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: () {},
                      child: const Text(
                        'إنشاء حساب',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              // **والوردُ فوق القوس لا تحته** — يغطّي ساقَيه كما في صورته، وكان
              // القوسُ يُرسم أمامَه في الرسمة الأولى. **وفوق الزرّين لا عليهما.**
              Positioned(
                left: 0,
                right: 0,
                bottom: 146,
                child: IgnorePointer(child: _Roses(roses)),
              ),
            ],
          ),
        ),
      );
  }
}

Widget _cell(String label, Widget screen) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
        SizedBox(
          width: 392,
          height: 820,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: screen,
          ),
        ),
      ],
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('اليوم والمقترح', (tester) async {
    tester.view.physicalSize = const Size(1330, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);
    final roses = File(Platform.environment['ROSES']!).readAsBytesSync();

    await tester.pumpWidget(MaterialApp(
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
        child: RepaintBoundary(
          key: const ValueKey('shot'),
          // **و`Material` لا `ColoredBox`**: بغيره لا يرث النصُّ خطَّ الثيمة
          // فتخرج العناوينُ مربّعات — وقد خرجت.
          child: Material(
            color: AppColors.surface2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _cell('اليوم — الشاشةُ الحقيقيّة',
                        WelcomeScreen(session: Session()..loading = false)),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _cell('(أ) الوردُ من صورتك — اخترتَه', _Proposal(roses)),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _cell('(ب) ومعه الزخرفةُ والنجوم',
                        _Proposal(roses, ornate: true)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    // **ولا `pumpAndSettle`**: للقوس نبضٌ يدور أبداً، فلا يستقرّ المشهد.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
    }

    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')))
          .toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/welcome-roses.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
    expect(tester.takeException(), isNull);
  });
}
