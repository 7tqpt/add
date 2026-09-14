// راسمُ فيديو شاشة الانطلاق **بعد التنفيذ** — ليس اختباراً، ولا يُدرج في
// الحزمة (خارج `test/`).
//
//   SHOTS=<مجلّد> flutter test tool/splash_shot_test.dart
//   ثمّ:  python3 tool/make_gif.py <مجلّد> done.gif
//
// كان مقترحاً بخيارين عُرض على صاحب المنصّة فيديوَ GIF قبل أن يُلمَس `lib/`
// (`splash_proposal_test.dart`)، فاختار **(أ) نبضٌ وتوهّج**. فسقط المرسومُ
// وبقيت الشاشةُ الحقيقيّة.
//
// ── ولا مرسومَ هنا ──────────────────────────────────────────────────────────
//
// **`BootScreen` بعينها** — الشيفرةُ المشحونة، بمقودَيها ومؤقّتها. ولا يُلقَّن
// الزمنُ تلقيناً: تُدفع الساعةُ إطاراً إطاراً كما تمشي في الجهاز، فما يُرى
// هنا هو ما يقع هناك.
//
// **وخليّتان: سريعةٌ وبطيئة.** أكثرُ الإقلاعات تنتهي قبل نصف الثانية، وقليلٌ
// منها يطول على شبكةٍ متعثّرة. والثانيةُ وحدَها يُكشف فيها الدوّارُ وسطرُه —
// وهو ما يُرى في الفيديو بعد الثانية السابعة عشرة من عشرين.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/welcome.dart';
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
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

class _Board extends StatelessWidget {
  const _Board();

  static const double _w = 300;
  static const double _h = 560;

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
                child: _cell('شاشةُ الانطلاق — كما صارت',
                    'المشهدُ يمضي فوق ما يقع تحته، ولا يحبس الشاشةَ لحظةً',
                    const BootScreen()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _cell('ولمن طال انتظارُه',
                    'يُكشف الدوّارُ وسطرُه بعد المشهد — لا قبله',
                    const BootScreen(label: 'جارٍ التحقق…')),
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

/// عشرون إطاراً في الثانية، ثلاثُ ثوانٍ.
const _fps = 20;
const _frames = 60;

void main() {
  setUpAll(_loadFonts);
  // الراسمُ ليس في `test/` فيشكو المحلّلُ من `@visibleForTesting`، والوسمُ
  // في موضعه: يمنع `lib/` أن تنادي الساعةَ فتُعيدها على مستخدمٍ حقيقيّ.
  // ignore: invalid_use_of_visible_for_testing_member
  setUp(resetIntroClock);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('الإطارات', (tester) async {
    tester.view.physicalSize = const Size(1320, 1300);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    Directory(out).createSync(recursive: true);

    await tester.pumpWidget(_wrap(const _Board()));
    // **وتُمهَل الأيقونةُ زمناً حقيقيّاً حتى تُفكّ** — `Image.asset` تقرأ من
    // الحزمة وتفكّ الترميزَ في خيطٍ آخر. وبلا هذا يخرج المشهدُ بلا شعار.
    for (var k = 0; k < 4; k++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump(const Duration(milliseconds: 1));
    }

    for (var i = 0; i < _frames; i++) {
      await _shoot(tester, find.byKey(const ValueKey('shot')),
          '$out/frame_${i.toString().padLeft(3, '0')}.png');
      // **والساعةُ تمشي إطاراً إطاراً** — لا تُلقَّن قيمةً. فالمؤقّتُ يُفجَّر
      // في موضعه والتدرّجُ يمشي كما يمشي في الجهاز.
      await tester.pump(const Duration(milliseconds: 1000 ~/ _fps));
    }

    // **ولا يُصدَّق أنّ المشهدَ رُسم: تُسأل الشجرة.**
    expect(find.byType(BootScreen), findsNWidgets(2));
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('فرحتي'), findsNWidgets(2));
    expect(find.byType(BrandSpinner), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
