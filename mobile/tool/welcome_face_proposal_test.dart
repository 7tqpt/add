// **مقترحٌ لا تنفيذ.** «عند ضغط ابدأ رحلتك خلّه ينطلق إلى تسجيل الدخول وليس
// إنشاء الحساب» — يُعرض قبل أن يُلمَس `lib/`.
//
//   SHOTS=<مجلّد> flutter test tool/welcome_face_proposal_test.dart
//
// ── ولا مرسومَ هنا ──────────────────────────────────────────────────────────
//
// **الخلايا الثلاثُ مصوَّرةٌ كلُّها من الشيفرة المدفوعة.** الوجهان موجودان
// في `AuthScreen` اليوم — الفرقُ بينهما مُعامِلٌ واحدٌ (`startOnSignUp`)، لا
// شيفرةٌ تُكتب. فما يُرى هنا هو ما سيُرى في الجهاز حرفاً بحرف.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/auth.dart';
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

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Session _guest() => Session()..loading = false;

class _Sheet extends StatelessWidget {
  const _Sheet({required this.cells});
  final List<({String label, String sub, Widget screen})> cells;

  static const double _w = 392;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFE9E1DB),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cells.length; i++)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: _w,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2, right: 2),
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
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, right: 2),
                          child: Text(
                            cells[i].sub,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: AppColors.muted,
                              fontFamilyFallback: arabicFallback,
                            ),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            key: ValueKey('cell$i'),
                            height: 720,
                            child: cells[i].screen,
                          ),
                        ),
                      ],
                    ),
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
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(key: const ValueKey('shot'), child: child),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('اللوح', (tester) async {
    tester.view.physicalSize = const Size(3800, 2600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_Sheet(cells: [
      (
        label: 'الترحيب — ومنه يُضغط «ابدأ رحلتك»',
        sub: 'وهو زرُّها الوحيد',
        screen: WelcomeScreen(session: _guest()),
      ),
      (
        label: 'اليوم — ينطلق إلى «إنشاء حساب»',
        sub: 'وبابُ العائد زرٌّ محاطٌ في قاعها: «دخول»',
        screen: AuthScreen(session: _guest(), startOnSignUp: true),
      ),
      (
        label: 'المقترح — ينطلق إلى «دخول الحساب»',
        sub: 'وبابُ الجديد زرٌّ محاطٌ في قاعها: «إنشاء حساب»',
        screen: AuthScreen(session: _guest()),
      ),
    ])));
    await _settle(tester);
    await _settleImages(tester);

    // **ولا يُصدَّق أنّ الوجهين افترقا: تُسأل الشجرة.**
    expect(find.text('ابدأ رحلتك'), findsOneWidget);
    expect(find.text('إنشاء حساب'), findsNWidgets(2)); // عنوانُ (٢) وزرُّ (٣)
    expect(find.text('دخول الحساب'), findsOneWidget);
    expect(find.byKey(const ValueKey('remember-me')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _shoot(tester, find.byKey(const ValueKey('shot')),
        '$out/welcome-face.png');
  });
}
