// **شريطُ حركة الترحيب** — إطاراتٌ من `WelcomeScreen` الحقيقيّة، لا رسم.
//
//   SHOTS=<مجلّد> flutter test tool/welcome_motion_shot_test.dart
//
// يكتب `frame-000.png`… ومعها `frames.txt` بمدّة كلّ إطار، فتُجمع صورةً
// متحرّكة. الدخولُ كلُّه بإطارٍ كلَّ ٨٠ جزءاً من الثانية، ثمّ دورةُ الحياة
// كاملةً (تسعُ ثوانٍ) بإطارٍ كلَّ ١٥٠.
import 'dart:io';
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

void main() {
  setUpAll(_loadFonts);

  testWidgets('حركةُ الترحيب', (tester) async {
    tester.view.physicalSize = const Size(392, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);

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
          child: WelcomeScreen(session: Session()..loading = false),
        ),
      ),
    ));
    // الوردُ يُفكّ على خيطٍ آخر — **ولا تتقدّم الساعةُ المزيّفةُ في أثناء ذلك**.
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    }

    final durations = <int>[];
    var n = 0;
    Future<void> grab(int ms) async {
      await tester.runAsync(() async {
        final image = await tester
            .renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')))
            .toImage(pixelRatio: 1.0);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        File('$out/frame-${n.toString().padLeft(3, '0')}.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      });
      durations.add(ms);
      n++;
    }

    await tester.pump();
    for (var ms = 0; ms < 1900; ms += 80) {
      await grab(80);
      await tester.pump(const Duration(milliseconds: 80));
    }
    for (var ms = 0; ms < 9000; ms += 150) {
      await grab(150);
      await tester.pump(const Duration(milliseconds: 150));
    }
    File('$out/frames.txt').writeAsStringSync(durations.join('\n'));
    expect(tester.takeException(), isNull);
  });
}
