// **تصويرُ ما صار.** هيكلُ التحميل في شاشةٍ حقيقيّة.
//
//   SHOTS=<مجلّد> flutter test tool/skeleton_shot_test.dart
//
// **وهي `MyBookingsScreen` نفسُها** — تُبنى ويُضخّ إطارٌ واحدٌ قبل أن تصل
// صفوفُها، فما في اللقطة هو ما يراه صاحبُ الجهاز في تلك اللحظة. ولا يُنتظر
// وصولُها: الانتظارُ هو المصوَّر.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/my_bookings.dart';
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

void main() {
  setUpAll(() async {
    await _loadFonts();
    await initFormatting();
  });

  testWidgets('الهيكل', (tester) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('shot'),
      child: MaterialApp(
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
          child: Scaffold(
            body: MyBookingsScreen(
              session: Session()
                ..userId = 'u1'
                ..appUserId = 'demo-user'
                ..loading = false,
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    // نصفُ نبضةٍ: الهيكلُ ينبض، فتُلتقط لحظةٌ وسط لا طرف.
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(SkeletonList), findsOneWidget,
        reason: 'لا هيكلَ يُصوَّر — الصفوفُ وصلت قبل اللقطة');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('shot')));
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$out/skeleton-done.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
