// **مقترحٌ لا تنفيذ.** «زيد حقل تأكيد كلمة المرور» — يُعرض قبل أن يُلمَس
// `lib/`.
//
//   SHOTS=<مجلّد> flutter test tool/confirm_password_proposal_test.dart
//
// ── ما هو مصوَّرٌ وما هو مرسوم ───────────────────────────────────────────────
//
// **الخليّتان (١) و(٣) مصوَّرتان من الشيفرة المدفوعة** — `RecoverPasswordScreen`
// سِيقت بالضغط إلى خطوتها الثالثة، و`AuthScreen` على وجه الإنشاء. وحقلُ
// الكلمة الواحدُ فيهما هو ما في الجهاز اليوم.
//
// **والخليّة (٢) مرسومةٌ ويُقال** — حقلُ التأكيد غيرُ منفَّذٍ بعد. لكنّها
// بُنيت بثيمة التطبيق (`buildTheme()`) وبـ`TextField` بالزينة نفسِها
// (`labelText` و`helperText` و`obscureText`) لا بصندوقٍ مرسوم.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/auth.dart';
import 'package:aras/src/screens/recover_password.dart';

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

Widget _pushed(Widget child) => Navigator(
      onGenerateInitialRoutes: (nav, _) => [
        MaterialPageRoute<void>(
            builder: (_) => const ColoredBox(color: AppColors.page)),
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: recoverRouteName),
          builder: (_) => child,
        ),
      ],
    );

/// (٢) خطوةُ الكلمة الجديدة **ومعها حقلُ التأكيد** — مرسومة.
class _WithConfirm extends StatelessWidget {
  const _WithConfirm();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.accentInk,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(tr('استعادة كلمة المرور')),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Space.lg, Space.xl, Space.lg, Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr('اكتب كلمة المرور الجديدة لحسابك.'),
                  style: const TextStyle(height: 1.7),
                ),
                const SizedBox(height: Space.md),
                TextField(
                  controller: TextEditingController(text: '••••••••••'),
                  obscureText: true,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: tr('كلمة المرور الجديدة'),
                    helperText: tr('ثمانية أحرف فأكثر.'),
                  ),
                ),
                const SizedBox(height: Space.md),
                // ── الحقلُ المقترَح ───────────────────────────────────────
                TextField(
                  controller: TextEditingController(text: '••••••••'),
                  obscureText: true,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: tr('أعِد كتابة الكلمة الجديدة'),
                  ),
                ),
                const SizedBox(height: Space.md),
                // وما يقع حين تختلفان.
                Text(
                  tr('الكلمتان غير متطابقتين.'),
                  style: const TextStyle(
                    color: AppColors.critical,
                    fontSize: 13,
                    height: 1.6,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
                const SizedBox(height: Space.lg),
                FilledButton(
                  onPressed: () {},
                  child: Text(tr('حفظ الكلمة الجديدة')),
                ),
              ],
            ),
          ),
        ),
      );
}

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
                            height: 620,
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

Finder _in(int cell, Key key) => find.descendant(
      of: find.byKey(ValueKey('cell$cell')),
      matching: find.byKey(key),
    );

void main() {
  setUpAll(_loadFonts);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('اللوح', (tester) async {
    tester.view.physicalSize = const Size(3800, 2300);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_Sheet(cells: [
      (
        label: '١) خطوةُ الكلمة الجديدة — اليوم',
        sub: 'حقلٌ واحد. مصوَّرةٌ من الشيفرة المدفوعة.',
        screen: _pushed(RecoverPasswordScreen(session: _guest())),
      ),
      (
        label: '٢) المقترح — وتحته حقلُ التأكيد',
        sub: 'مرسومةٌ بعناصر التطبيق وثيمته — الحقلُ غيرُ منفَّذٍ بعد',
        screen: const _WithConfirm(),
      ),
      (
        label: '٣) وإنشاءُ الحساب — اليوم',
        sub: 'حقلٌ واحدٌ كذلك، والخطأُ فيه يحبس صاحبَه خارجَ حسابه',
        screen: AuthScreen(session: _guest(), startOnSignUp: true),
      ),
    ])));
    await _settle(tester);
    await _settleImages(tester);

    // تُساق الخليّةُ الأولى إلى خطوتها الثالثة **بالضغط لا بالتلقين**.
    await tester.enterText(
        _in(0, const ValueKey('recover-email')), 'ayman@sdd.company');
    await tester.tap(_in(0, const ValueKey('recover-go')));
    await _settle(tester);
    await tester.enterText(_in(0, const ValueKey('recover-code')), '482910');
    await tester.tap(_in(0, const ValueKey('recover-go')));
    await _settle(tester);
    await tester.enterText(
        _in(0, const ValueKey('recover-new-password')), 'كلمةٌ طويلة');
    await _settle(tester);
    await _settleImages(tester);

    // **ولا يُصدَّق أنّ الخطوةَ بُلغت: تُسأل الشجرة.**
    expect(_in(0, const ValueKey('recover-new-password')), findsOneWidget);
    expect(find.text('كلمة المرور الجديدة'), findsNWidgets(2));
    expect(find.text('أعِد كتابة الكلمة الجديدة'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'إنشاء الحساب'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _shoot(tester, find.byKey(const ValueKey('shot')),
        '$out/confirm-password.png');
  });
}
