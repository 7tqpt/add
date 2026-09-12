// راسمُ ما يفتحه «ابدأ رحلتك» — `AuthScreen` على وجه «إنشاء الحساب».
//
//   SHOTS=<مجلّد> flutter test tool/auth_shot_test.dart
//
// **واللقطةُ حقيقيّةٌ:** الشاشةُ نفسُها بثيمة التطبيق. وعُرضت على صاحب
// المنصّة حين حُذفت صفحةُ «اختر نوع الحساب»، ليرى ما صار يفتحه الزرّ.
//
// **ووجهُ «الدخول» لا يُصوَّر هنا.** كتبتُ له اختباراً ثانياً فتعلّق ولم
// يُخرج لقطته — وترك راسمٍ يتعلّق في الشجرة أسوأُ من نقص لقطة: يُشغَّل يوماً
// فيُظنّ العطبُ في التطبيق. والوجهان يفترقان بزرٍّ ونصّين، وشجرةُ العناصر
// تقيسهما في `test/welcome_test.dart` — وهو أدقُّ من الصورة على كلّ حال.
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

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  // **ولا `pumpAndSettle`:** في الشاشة حقولُ نصّ، ومؤشّرُ الكتابة ينبض
  // فلا تسكن الإطاراتُ أبداً.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('إنشاءُ الحساب', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(
        AuthScreen(session: Session()..loading = false, startOnSignUp: true)));
    await settle(tester);
    expect(find.widgetWithText(FilledButton, 'إنشاء الحساب'), findsOneWidget);
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/auth-signup.png');
  });
}
