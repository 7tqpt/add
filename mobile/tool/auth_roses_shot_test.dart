// **لقطاتُ شاشات الباب بعد التنفيذ** — الشاشاتُ الحقيقيّة، لا رسم.
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

import 'package:aras/src/core/app_lock.dart';
import 'package:aras/src/core/biometrics.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/auth.dart';
import 'package:aras/src/screens/lock.dart';
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
  await initializeDateFormatting('ar');
}

/// بصمةٌ في «الجهاز» لا تطابق — فتبقى الشاشةُ مقفلةً للّقطة.
class _Sensor implements Biometrics {
  @override
  Future<bool> available() async => true;
  @override
  Future<bool> authenticate() async => false;
}

final _w = double.parse(Platform.environment['WIDTH'] ?? '392');
final _h = double.parse(Platform.environment['HEIGHT'] ?? '800');

Future<void> _shoot(WidgetTester tester, Widget screen, String name) async {
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
  setUp(() => lockStorageOverride = {});
  tearDown(() {
    lockStorageOverride = null;
    biometricsOverride = null;
  });

  testWidgets('الدخول', (t) => _shoot(t, AuthScreen(session: Session()..loading = false), 'a-signin'));
  testWidgets(
      'الإنشاء',
      (t) => _shoot(
          t, AuthScreen(session: Session()..loading = false, startOnSignUp: true), 'b-signup'));
  testWidgets(
      'الاستعادة',
      (t) => _shoot(
          t, RecoverPasswordScreen(session: Session()..loading = false), 'c-recover'));
  testWidgets('القفل', (tester) async {
    biometricsOverride = _Sensor();
    final lock = AppLock();
    await lock.enable('1234');
    await lock.setBiometric(true);
    lock.onLeave();
    lock.onReturn();
    await _shoot(tester, LockScreen(lock: lock, onSignOut: () async {}), 'd-lock');
  });
}
