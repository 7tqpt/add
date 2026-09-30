// **مقترحُ شاشات الدخول على تصميم صاحب المنصّة** — قبل أن يُلمس `lib/`.
//
//   SHOTS=<مجلّد> flutter test tool/auth_roses_proposal_test.dart
//
// أرسل أربعَ صورٍ: الدخول، والإنشاء، والاستعادة، والقفل — وقال: «نفذهم
// بنفس الاستيل». **وهذه مركّبةٌ في الراسم** من قطع التطبيق نفسِها وبثيمته
// وخطوطه: `ArchPainter` و`starAt` و`WelcomeRoses.asset` و`buildTheme()`.
//
// - **الوردُ من صورته السابقة** (`welcome_roses.webp`) — طرفاه يُقصّان في
//   زاويتي الرأس. ولم يُقصّ من الصور الجديدة لأنّ خطَّ القوس والنجومَ
//   مرسومةٌ فوق الورد فيها.
// - **والحريرُ في الأسفل مرسومٌ بالشيفرة** لا مقصوص: تدرّجٌ كريميٌّ وخيوطٌ
//   ذهبيّة.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

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

// ── الألوانُ المأخوذةُ من صوره ─────────────────────────────────────────────
const _paper = Color(0xFFFFFDFA); // البطاقة
const _cream = Color(0xFFF7EEDF); // الحرير
const _goldLine = Color(0xFFE3CB9B); // إطارُ الحقول والبطاقة
const _goldText = Color(0xFF9A6B18); // «أهلاً بعودتك» = AppColors.gold

// ── الإطار: رأسٌ نبيذيٌّ بقوسٍ وورد، وبطاقةٌ عائمةٌ على حرير ─────────────────
class _Frame extends StatelessWidget {
  const _Frame({required this.crest, required this.card, this.title});
  final Widget crest;
  final List<Widget> card;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final head = (size.height * 0.25).clamp(150.0, 220.0) + (title == null ? 0 : 44);
    return Scaffold(
      backgroundColor: _cream,
      body: Stack(
        children: [
          // الحرير
          const Positioned.fill(child: CustomPaint(painter: _SilkPainter())),
          // الرأس
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: head,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.accentDeep, AppColors.accent],
                ),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(child: _Lattice()),
                  const Positioned.fill(child: CustomPaint(painter: _Stars())),
                  // القوس — ساقاه تحت البطاقة.
                  Positioned(
                    left: size.width * 0.19,
                    right: size.width * 0.19,
                    top: 14 + (title == null ? 0 : 44),
                    bottom: -40,
                    child: CustomPaint(
                      painter: const ArchPainter(),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 36, bottom: 40),
                        child: Center(child: crest),
                      ),
                    ),
                  ),
                  if (title != null)
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          const IconButton(
                            onPressed: null,
                            icon: Icon(Icons.arrow_forward, color: AppColors.goldOnAccent),
                          ),
                          Text(title!,
                              style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.goldOnAccent)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // الوردُ في الزاويتين — طرفا شريط الترحيب.
          Positioned(top: head - 130, left: -12, width: 124, height: 170, child: const _Corner(left: true)),
          Positioned(top: head - 130, right: -12, width: 124, height: 170, child: const _Corner(left: false)),
          // البطاقة
          Positioned.fill(
            top: head - 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                decoration: BoxDecoration(
                  color: _paper,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _goldLine.withValues(alpha: 0.7)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentDeep.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: card,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.left});
  final bool left;

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => RadialGradient(
          center: left ? const Alignment(-1, 0.3) : const Alignment(1, 0.3),
          radius: 1.05,
          colors: const [Colors.black, Colors.black, Colors.transparent],
          stops: const [0, 0.6, 1],
        ).createShader(r),
        child: ShaderMask(
         blendMode: BlendMode.dstIn,
         shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
          stops: [0, 0.35],
         ).createShader(r),
         child: ClipRect(
          child: OverflowBox(
            maxWidth: 360,
            alignment: left ? Alignment.centerLeft : Alignment.centerRight,
            child: Image.asset(
              WelcomeRoses.asset,
              height: 170,
              fit: BoxFit.fitHeight,
              alignment: left ? Alignment.centerLeft : Alignment.centerRight,
            ),
          ),
         ),
        ),
      );
}

class _Lattice extends StatelessWidget {
  const _Lattice();
  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const RadialGradient(
          center: Alignment(0, 0),
          radius: 0.9,
          colors: [Colors.transparent, Colors.transparent, Colors.black],
          stops: [0, 0.5, 1],
        ).createShader(r),
        child: const CustomPaint(painter: _LatticePainter(), size: Size.infinite),
      );
}

class _LatticePainter extends CustomPainter {
  const _LatticePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = AppColors.goldOnAccent.withValues(alpha: 0.10);
    const step = 34.0;
    for (var y = -step; y < size.height + step; y += step) {
      final odd = (y / step).round().isOdd;
      for (var x = -step; x < size.width + step; x += step) {
        canvas.drawCircle(Offset(x + (odd ? step / 2 : 0), y), step * 0.62, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_LatticePainter old) => false;
}

class _Stars extends CustomPainter {
  const _Stars();
  static const _light = Color(0xFFFFE7A8);
  // مواضعُ صوره: حول القوس وداخله.
  static const _spots = [
    (0.17, 0.30, 6.0), (0.72, 0.18, 8.0), (0.62, 0.42, 3.5), (0.29, 0.62, 6.0), (0.88, 0.70, 4.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _spots.length; i++) {
      final (x, y, r) = _spots[i];
      final a = starAt(i, 0.3).alpha;
      final c = Offset(x * size.width, y * size.height);
      canvas.drawCircle(
        c,
        r * 1.8,
        Paint()
          ..shader = RadialGradient(colors: [
            _light.withValues(alpha: 0.45 * a),
            _light.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: c, radius: r * 1.8)),
      );
      final path = Path()..moveTo(c.dx, c.dy - r);
      for (var k = 1; k <= 4; k++) {
        final ang = -math.pi / 2 + k * math.pi / 2;
        path.quadraticBezierTo(c.dx, c.dy, c.dx + r * math.cos(ang), c.dy + r * math.sin(ang));
      }
      canvas.drawPath(path, Paint()..color = _light.withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(_Stars old) => false;
}

class _SilkPainter extends CustomPainter {
  const _SilkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFBF6EE), _cream, Color(0xFFF1E3CC)],
        ).createShader(rect),
    );
    // طيّاتٌ ليّنةٌ وخيوطٌ ذهبيّة في الثلث الأسفل.
    final fold = Paint()..color = Colors.white.withValues(alpha: 0.45);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFD9B26A).withValues(alpha: 0.55);
    final h = size.height, w = size.width;
    for (var k = 0; k < 3; k++) {
      final y0 = h * (0.74 + k * 0.08);
      final p = Path()
        ..moveTo(0, y0)
        ..cubicTo(w * 0.3, y0 - 60 + k * 20, w * 0.6, y0 + 50, w, y0 - 30 - k * 10);
      canvas.drawPath(
          Path.from(p)
            ..lineTo(w, h)
            ..lineTo(0, h)
            ..close(),
          fold);
      canvas.drawPath(p, line);
    }
  }

  @override
  bool shouldRepaint(_SilkPainter old) => false;
}

// ── قطعُ البطاقة ────────────────────────────────────────────────────────────
Widget _crest() => const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.favorite_rounded, size: 40, color: AppColors.goldOnAccent),
        SizedBox(height: 4),
        Text('فرحتي',
            style: TextStyle(
                fontSize: 44, height: 1.2, fontWeight: FontWeight.w700, color: AppColors.goldOnAccent)),
      ],
    );

Widget _title(String t) => Text(t,
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.accent));

Widget _sub(String t) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(t,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: _goldText)),
    );

Widget _heartRule() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 64, height: 1, color: _goldLine),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.favorite_rounded, size: 14, color: Color(0xFFD9A94E)),
          ),
          Container(width: 64, height: 1, color: _goldLine),
        ],
      ),
    );

InputDecoration _field(String label, IconData icon, {bool eye = false, String? helper}) => InputDecoration(
      labelText: label,
      helperText: helper,
      fillColor: const Color(0xFFFFFCF7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      // الرمزُ في الطرف الأيسر والعينُ قبل العنوان — كما في صورتَي الدخول.
      suffixIcon: Icon(icon, color: AppColors.ink2),
      prefixIcon: eye ? const Icon(Icons.visibility_outlined, color: AppColors.ink2) : null,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _goldLine),
      ),
    );

Widget _primary(String label) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.accentLift, AppColors.accent, AppColors.accentDeep],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.accent.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () {},
        child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
    );

Widget _outlined(String label) => OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: Color(0xFFD9B26A)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () {},
      child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
    );

Widget _foot() => const Padding(
      padding: EdgeInsets.only(top: 18),
      child: Text('تبدأ عميلاً، وإن أردت تقديم خدمة تطلبها من شاشة حسابك.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.7)),
    );

List<Widget> _signIn() => [
      _title('دخول الحساب'),
      _sub('أهلاً بعودتك'),
      _heartRule(),
      TextField(textDirection: TextDirection.ltr, decoration: _field('البريد الإلكتروني', Icons.mail_outline)),
      const SizedBox(height: 14),
      TextField(
          obscureText: true,
          textDirection: TextDirection.ltr,
          decoration: _field('كلمة المرور', Icons.lock_outline, eye: true)),
      const SizedBox(height: 6),
      Row(
        children: [
          TextButton(
            onPressed: () {},
            child: const Text('نسيت كلمة المرور؟',
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          const Text('تذكّرني', style: TextStyle(fontSize: 14, color: AppColors.ink2)),
          Checkbox(
            value: true,
            activeColor: AppColors.accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            onChanged: (_) {},
          ),
        ],
      ),
      const SizedBox(height: 6),
      _primary('دخول'),
      _heartRule(),
      const Text('ما عندك حساب؟', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 8),
      _outlined('إنشاء حساب'),
      _foot(),
    ];

List<Widget> _signUp() => [
      _title('إنشاء حساب'),
      _sub('بداية فرحتك من هنا'),
      _heartRule(),
      TextField(textDirection: TextDirection.ltr, decoration: _field('البريد الإلكتروني', Icons.mail_outline)),
      const SizedBox(height: 14),
      TextField(
          obscureText: true,
          textDirection: TextDirection.ltr,
          decoration: _field('كلمة المرور', Icons.lock_outline, eye: true, helper: 'ثمانية أحرف فأكثر.')),
      const SizedBox(height: 10),
      TextField(
          obscureText: true,
          textDirection: TextDirection.ltr,
          decoration: _field('أعِد كتابة كلمة المرور', Icons.lock_outline, eye: true)),
      const SizedBox(height: 18),
      _primary('إنشاء الحساب'),
      _heartRule(),
      const Text('عندك حساب؟', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 8),
      _outlined('دخول'),
      _foot(),
    ];

List<Widget> _recover() => [
      _title('نسيت كلمتك؟'),
      _heartRule(),
      const Text('اكتب بريدك الإلكترونيّ، ونرسل إليه رمزاً تستعيد به كلمتك.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.ink2, height: 1.7)),
      const SizedBox(height: 18),
      TextField(textDirection: TextDirection.ltr, decoration: _field('البريد الإلكتروني', Icons.mail_outline)),
      const SizedBox(height: 20),
      _primary('أرسل رمز الاستعادة'),
      const SizedBox(height: 8),
    ];

List<Widget> _lock({required bool indic}) {
  String d(String s) => indic ? '٠١٢٣٤٥٦٧٨٩'[int.parse(s)] : s;
  Widget key(Widget child, {bool tile = false}) => SizedBox(
        width: 84,
        height: 84,
        child: DecoratedBox(
          decoration: tile
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFBEFD6), Color(0xFFF1D9A6)],
                  ),
                  border: Border.all(color: const Color(0xFFD9B26A)),
                )
              : BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _goldLine)),
          child: Center(child: child),
        ),
      );
  Widget digit(String s) => key(Text(d(s),
      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: AppColors.accent)));
  Widget row(List<Widget> k) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: k),
      );
  return [
    Text.rich(
      const TextSpan(children: [
        TextSpan(text: 'أدخل رمز ', style: TextStyle(color: AppColors.ink)),
        TextSpan(text: 'القفل', style: TextStyle(color: AppColors.accent)),
      ]),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
    ),
    _sub('أربعة أرقام'),
    const SizedBox(height: 16),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD9B26A), width: 1.6),
            ),
          ),
      ],
    ),
    const SizedBox(height: 24),
    row([digit('1'), digit('2'), digit('3')]),
    row([digit('4'), digit('5'), digit('6')]),
    row([digit('7'), digit('8'), digit('9')]),
    row([
      key(const Icon(Icons.fingerprint, size: 44, color: AppColors.accent), tile: true),
      digit('0'),
      key(const Icon(Icons.backspace_outlined, size: 28, color: AppColors.accent)),
    ]),
    TextButton(
      onPressed: () {},
      child: const Text('نسيتُ الرمز',
          style: TextStyle(fontSize: 16, color: AppColors.accent, fontWeight: FontWeight.w600)),
    ),
  ];
}

Widget _app(Widget home) => MaterialApp(
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
        child: RepaintBoundary(key: const ValueKey('shot'), child: home),
      ),
    );

Future<void> _shoot(WidgetTester tester, Widget screen, String name, {double h = 800}) async {
  tester.view.physicalSize = Size(392, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
  Directory(out).createSync(recursive: true);
  await tester.pumpWidget(_app(screen));
  await tester.pump(const Duration(milliseconds: 400));
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
  }
  await tester.runAsync(() async {
    final image = await tester
        .renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')))
        .toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('الدخول', (t) => _shoot(t, _Frame(crest: _crest(), card: _signIn()), 'a-signin'));
  testWidgets('الإنشاء', (t) => _shoot(t, _Frame(crest: _crest(), card: _signUp()), 'b-signup'));
  testWidgets(
      'الاستعادة',
      (t) => _shoot(
          t,
          _Frame(
            title: 'استعادة كلمة المرور',
            crest: const Icon(Icons.lock_reset_rounded, size: 96, color: AppColors.goldOnAccent),
            card: _recover(),
          ),
          'c-recover'));
  testWidgets('القفل — أرقامٌ لاتينيّة',
      (t) => _shoot(t, _Frame(crest: _crest(), card: _lock(indic: false)), 'd-lock-latin', h: 820));
  testWidgets('القفل — أرقامٌ هنديّة',
      (t) => _shoot(t, _Frame(crest: _crest(), card: _lock(indic: true)), 'e-lock-indic', h: 820));
}
