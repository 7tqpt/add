// **لقطةُ «خطة جديدة» بعد التنفيذ** — الشاشاتُ الحقيقيّة، لا رسم.
//
//   SHOTS=<مجلّد> [WIDTH=392] [HEIGHT=800] flutter test tool/auth_roses_shot_test.dart
//
// `AuthScreen` بوجهيها، و`RecoverPasswordScreen`، و`LockScreen` ببصمةٍ
// مشغّلة — كلٌّ من شيفرته، والوردُ من أصله المشحون.
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
import 'package:aras/src/screens/plan_editor.dart';

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

final _w = double.parse(Platform.environment['WIDTH'] ?? '392');
final _h = double.parse(Platform.environment['HEIGHT'] ?? '800');

Future<void> _shoot(WidgetTester tester, Widget screen, String name, {Key? tap}) async {
  tester.view.physicalSize = Size(_w, _h);
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
      child: RepaintBoundary(key: const ValueKey('shot'), child: screen),
    ),
  ));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
  }
  if (tap != null) {
    await tester.tap(find.byKey(tap));
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.runAsync(() async {
    final image = await tester
        .renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')))
        .toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$out/$name-${_w.toInt()}x${_h.toInt()}.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
  });
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(_loadFonts);

  Session session() => Session()
    ..userId = 'u1'
    ..email = 'c@sdd.company'
    ..appUserId = 'demo-user'
    ..loading = false;

  testWidgets('خطة جديدة', (t) => _shoot(t, PlanEditorScreen(session: session()), 'plan-new'));
  testWidgets('خطة جديدة — «أنا عروس» مختارة', (t) async {
    await _shoot(t, PlanEditorScreen(session: session()), 'plan-bride', tap: const ValueKey('role-bride'));
  });
}
