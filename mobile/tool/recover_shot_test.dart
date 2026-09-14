// راسمُ لقطاتِ شاشة الاستعادة بعد التنفيذ — **ليس اختباراً**، ولا يُدرج في
// الحزمة (خارج `test/`).
//
//   SHOTS=<مجلّد> flutter test tool/recover_shot_test.dart
//
// **والعناصرُ كلُّها هي المشحونة بعينها** — `AuthScreen` و
// `RecoverPasswordScreen` بخطواتها الثلاث. ولا مرسومَ هنا كما كان في
// `recover_proposal_test.dart`: ذاك كان قبل التنفيذ ولم يكن في الشيفرة ما
// يُصوَّر.
//
// **والخطواتُ تُبلَغ بالضغط لا بالتلقين:** يُكتب البريدُ في الخليّة الثانية
// ويُضغط زرُّها، ثمّ الرمزُ في الثالثة ويُضغط زرُّها. فما يُرى هو ما يصل
// إليه الإصبعُ في الجهاز.
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
                            height: 640,
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

/// يضع الشاشةَ **مدفوعةً فوق غيرها** — وإلّا لم يظهر سهمُ الرجوع.
///
/// `automaticallyImplyLeading` ترسم السهمَ حين يكون تحت الشاشة شيءٌ يُرجَع
/// إليه. وخليّةٌ في لوحٍ ليست مدفوعةً على شيء، فيغيب السهمُ في اللقطة ويبقى
/// في الجهاز — لقطةٌ تكذب على صاحبها. فيُبنى لكلّ خليّةٍ ملاحٌ بطريقين.
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

/// عنصرٌ داخلَ خليّةٍ بعينها — واللوحُ فيه أربعُ شاشاتٍ متشابهةٌ المفاتيح.
Finder _in(int cell, Key key) => find.descendant(
      of: find.byKey(ValueKey('cell$cell')),
      matching: find.byKey(key),
    );

void main() {
  setUpAll(_loadFonts);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('اللوح', (tester) async {
    tester.view.physicalSize = const Size(6260, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_Sheet(cells: [
      (
        label: 'الدخول — ومنه تُضغط «نسيت كلمة المرور»',
        sub: 'ولا ترسل شيئاً ولا تسأل عن بريدٍ لم يُكتب',
        screen: AuthScreen(session: _guest()),
      ),
      (
        label: '١) الحقلُ الذي تفتحه الضغطة',
        sub: 'والمؤشّرُ فيه من أوّل لحظة',
        screen: _pushed(RecoverPasswordScreen(session: _guest())),
      ),
      (
        label: '٢) ثمّ الرمزُ الواصلُ إلى البريد',
        sub: 'ولا يُقال إن كان البريدُ مسجّلاً أو غيرَ مسجّل',
        screen: _pushed(RecoverPasswordScreen(session: _guest())),
      ),
      (
        label: '٣) ثمّ الكلمةُ الجديدة ومعها تأكيدُها',
        sub: 'ولا سهمَ رجوع: الجلسةُ فُتحت بالرمز، والخروجُ هنا يترك صاحبَها بكلمةٍ لا يعرفها',
        screen: _pushed(RecoverPasswordScreen(session: _guest())),
      ),
      (
        label: '٤) وإنشاءُ الحساب — وفيه التأكيدُ كذلك',
        sub: 'وخطأُ المُنشئ لا يُردّ عليه أبداً: يُحفظ كلمةً وينجح الحساب',
        screen: AuthScreen(session: _guest(), startOnSignUp: true),
      ),
    ])));
    await _settle(tester);
    await _settleImages(tester);

    // ── تُبلَغ الخطواتُ بالضغط ────────────────────────────────────────────
    await tester.enterText(
        _in(2, const ValueKey('recover-email')), 'ayman@sdd.company');
    await tester.tap(_in(2, const ValueKey('recover-go')));
    await _settle(tester);

    await tester.enterText(
        _in(3, const ValueKey('recover-email')), 'ayman@sdd.company');
    await tester.tap(_in(3, const ValueKey('recover-go')));
    await _settle(tester);
    await tester.enterText(_in(3, const ValueKey('recover-code')), '482910');
    await tester.tap(_in(3, const ValueKey('recover-go')));
    await _settle(tester);
    await _settleImages(tester);

    // **ولا يُصدَّق أنّ الخطواتِ بُلغت: تُسأل الشجرة.**
    expect(_in(1, const ValueKey('recover-email')), findsOneWidget);
    expect(_in(2, const ValueKey('recover-code')), findsOneWidget);
    expect(_in(3, const ValueKey('recover-new-password')), findsOneWidget);
    expect(_in(3, const ValueKey('recover-confirm-password')), findsOneWidget);
    expect(_in(4, const ValueKey('signup-confirm-password')), findsOneWidget);
    // وسهمُ الرجوع في الأوليين لا في الثالثة.
    expect(find.byType(BackButton), findsNWidgets(2));
    expect(find.text('نسيت كلمة المرور'), findsOneWidget);
    expect(find.text('اكتب بريدك أوّلاً.'), findsNothing);
    expect(tester.takeException(), isNull);

    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/recover-done.png');
  });
}
