// **لقطةُ الترحيب بعد التنفيذ** — الشاشةُ الحقيقيّة، لا رسم.
//
//   SHOTS=<مجلّد> flutter test tool/welcome_roses_shot_test.dart
//
// `WelcomeScreen` بعينها: الوردُ من أصلها المشحون، والزخرفةُ والنجومُ
// والزرُّ الذهبيّ من شيفرتها.
//
// **الأولى الشاشةُ الحقيقيّة اليوم** (`WelcomeScreen`). **والثانيةُ مركّبةٌ
// في الراسم من قطع التطبيق نفسِها**: `BrandBackdrop` و`ArchMark` — القوسُ
// والقلبُ والاسمُ وحركتُها — والزرّان. والجديدُ فيها شيئان:
//
// - **شريطُ الورد والمخمل مقصوصٌ من صورة صاحب المنصّة نفسِها** (عرضُه
//   ‎٨٧١‎ بكسلاً)، يذوب أعلاه في الأرضيّة فلا يُرى له حدّ.
// - **و«دخول» بتدرّجٍ ذهبيّ** كما في صورته، لا ذهباً مصمتاً.
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

  testWidgets('الترحيب', (tester) async {
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
    // **ولا `pumpAndSettle`**: النجومُ تومض أبداً فلا يستقرّ المشهد.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    // والأصلُ يُفكّ على خيطٍ آخر.
    for (var i = 0; i < 4; i++) {
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
      File('$out/welcome-after.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
    expect(tester.takeException(), isNull);
  });
}
